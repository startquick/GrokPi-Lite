package token

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"strings"
	"time"

	http "github.com/bogdanfinn/fhttp"
	tls_client "github.com/bogdanfinn/tls-client"
	"github.com/crmmc/grokpi/internal/config"
	"github.com/crmmc/grokpi/internal/store"
	"github.com/crmmc/grokpi/internal/xai"
)

var (
	// ErrNoQuota is returned when token has no remaining quota.
	ErrNoQuota = errors.New("no quota remaining")
	// ErrTokenNotFound is returned when token ID does not exist.
	ErrTokenNotFound = errors.New("token not found")
)

// ImportProfile captures the upstream-derived plan classification for a token.
type ImportProfile struct {
	Pool              string
	Priority          int
	ChatQuota         int
	InitialChatQuota  int
	ImageQuota        int
	InitialImageQuota int
	VideoQuota        int
	InitialVideoQuota int
}

// RateLimitsRequest is the request body for rate-limits API.
type RateLimitsRequest struct {
	RequestKind string `json:"requestKind"`
	ModelName   string `json:"modelName"`
}

// RateLimitsResponse is the response from rate-limits API.
type RateLimitsResponse struct {
	RemainingQueries  int `json:"remainingQueries"`
	WindowSizeSeconds int `json:"windowSizeSeconds"`
}

const rateLimitsPath = "/rest/rate-limits"
const minCoolingDuration = 5 * time.Minute

// defaultSuperQuotaThreshold is the fallback classification threshold when config is zero.
// Chosen to sit safely between observed free tier (60) and SuperGrok (140).
const defaultSuperQuotaThreshold = 100

// Consume deducts quota from the token for the given category.
// cost allows variable deduction for different model types.
// Returns remaining quota after deduction.
func (m *TokenManager) Consume(tokenID uint, cat QuotaCategory, cost int) (remaining int, err error) {
	m.mu.Lock()
	defer m.mu.Unlock()

	token, ok := m.tokens[tokenID]
	if !ok {
		return 0, ErrTokenNotFound
	}

	cur := GetQuota(token, cat)
	if cur <= 0 {
		return 0, ErrNoQuota
	}

	if cost <= 0 {
		cost = 1
	}
	newVal := cur - cost
	if newVal < 0 {
		newVal = 0
	}
	SetQuota(token, cat, newVal)

	now := time.Now()
	token.LastUsed = &now

	// Only enter cooling if ALL categories are exhausted
	if token.ChatQuota <= 0 && token.ImageQuota <= 0 && token.VideoQuota <= 0 {
		coolUntil := now.Add(m.coolingDurationForToken(token))
		token.Status = string(StatusCooling)
		token.CoolUntil = &coolUntil
	}
	m.dirty[tokenID] = struct{}{}

	return newVal, nil
}

// SyncQuota fetches quota from upstream API and updates token state.
// The upstream rate-limits API returns a single remainingQueries value
// which maps to ChatQuota (the primary category).
// If quota recovered and token is cooling, restores to active.
func (m *TokenManager) SyncQuota(ctx context.Context, token *store.Token, baseURL string) error {
	resp, err := fetchRateLimits(ctx, token.Token, baseURL)
	if err != nil {
		return fmt.Errorf("fetch rate limits: %w", err)
	}

	m.mu.Lock()
	defer m.mu.Unlock()

	token.ChatQuota = resp.RemainingQueries
	token.InitialChatQuota = resp.RemainingQueries

	// Auto-assign Pool and Priority based on quota capacity.
	// Premium accounts typically receive materially higher query limits.
	threshold := m.superQuotaThreshold()
	if token.InitialChatQuota >= threshold {
		if token.Pool == "" {
			token.Pool = PoolSuper
		}
		if token.Priority == 0 {
			token.Priority = 10
		}
	} else {
		if token.Pool == "" {
			token.Pool = PoolBasic
		}
	}

	// Restore image/video quotas to configured defaults on sync
	if m.cfg.DefaultImageQuota > 0 {
		token.ImageQuota = m.cfg.DefaultImageQuota
		token.InitialImageQuota = m.cfg.DefaultImageQuota
	}
	if m.cfg.DefaultVideoQuota > 0 {
		token.VideoQuota = m.cfg.DefaultVideoQuota
		token.InitialVideoQuota = m.cfg.DefaultVideoQuota
	}

	switch {
	case resp.RemainingQueries > 0 && Status(token.Status) == StatusCooling:
		// Restore cooling token to active if quota recovered
		token.Status = string(StatusActive)
		token.StatusReason = ""
		token.CoolUntil = nil
		token.FailCount = 0
	case resp.RemainingQueries <= 0 && Status(token.Status) == StatusActive:
		// Prevent zombie: active token with no quota must enter cooling
		now := time.Now()
		token.Status = string(StatusCooling)
		token.CoolUntil = &now
	}

	m.dirty[token.ID] = struct{}{}
	return nil
}

// fetchRateLimits calls the rate-limits API.
func fetchRateLimits(ctx context.Context, authToken, baseURL string) (*RateLimitsResponse, error) {
	reqBody := RateLimitsRequest{
		RequestKind: "DEFAULT",
		ModelName:   "grok-3",
	}

	body, err := json.Marshal(reqBody)
	if err != nil {
		return nil, err
	}

	url := baseURL + rateLimitsPath
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return nil, err
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Cookie", "sso="+authToken)

	client, err := tls_client.NewHttpClient(nil, tls_client.WithTimeoutSeconds(10))
	if err != nil {
		return nil, err
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, classifyRateLimitsError(resp)
	}

	respBody, err := io.ReadAll(io.LimitReader(resp.Body, 1<<20))
	if err != nil {
		return nil, err
	}

	var result RateLimitsResponse
	if err := json.Unmarshal(respBody, &result); err != nil {
		return nil, err
	}

	return &result, nil
}

// DetectImportProfile queries upstream quota and derives a simple free vs paid
// classification using the existing pool model. Higher-capacity accounts map to
// PoolSuper with elevated priority; everything else maps to PoolBasic.
func DetectImportProfile(ctx context.Context, authToken, baseURL string, cfg *config.TokenConfig) (*ImportProfile, error) {
	resp, err := fetchRateLimits(ctx, authToken, baseURL)
	if err != nil {
		return nil, err
	}

	chatQuota := resp.RemainingQueries
	pool, priority := classifyQuotaCapacity(chatQuota, effectiveSuperQuotaThreshold(cfg))
	imageQuota := 20
	videoQuota := 10
	if cfg != nil {
		if cfg.DefaultImageQuota > 0 {
			imageQuota = cfg.DefaultImageQuota
		}
		if cfg.DefaultVideoQuota > 0 {
			videoQuota = cfg.DefaultVideoQuota
		}
	}

	return &ImportProfile{
		Pool:              pool,
		Priority:          priority,
		ChatQuota:         chatQuota,
		InitialChatQuota:  chatQuota,
		ImageQuota:        imageQuota,
		InitialImageQuota: imageQuota,
		VideoQuota:        videoQuota,
		InitialVideoQuota: videoQuota,
	}, nil
}

func classifyQuotaCapacity(chatQuota, threshold int) (pool string, priority int) {
	if threshold <= 0 {
		threshold = defaultSuperQuotaThreshold
	}
	if chatQuota >= threshold {
		return PoolSuper, 10
	}
	return PoolBasic, 0
}

// superQuotaThreshold returns the effective classification threshold from config.
func (m *TokenManager) superQuotaThreshold() int {
	return effectiveSuperQuotaThreshold(m.cfg)
}

// effectiveSuperQuotaThreshold resolves the threshold from a TokenConfig pointer (nil-safe).
func effectiveSuperQuotaThreshold(cfg *config.TokenConfig) int {
	if cfg != nil && cfg.SuperQuotaThreshold > 0 {
		return cfg.SuperQuotaThreshold
	}
	return defaultSuperQuotaThreshold
}

func classifyRateLimitsError(resp *http.Response) error {
	if resp == nil {
		return errors.New("rate-limits API returned nil response")
	}

	if resp.StatusCode == http.StatusForbidden {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		if looksLikeCloudflareChallenge(string(body), resp) {
			return xai.ErrCFChallenge
		}
		return fmt.Errorf("rate-limits API returned %d", resp.StatusCode)
	}

	return fmt.Errorf("rate-limits API returned %d", resp.StatusCode)
}

func looksLikeCloudflareChallenge(body string, resp *http.Response) bool {
	if resp == nil {
		return false
	}

	server := strings.ToLower(resp.Header.Get("Server"))
	contentType := strings.ToLower(resp.Header.Get("Content-Type"))
	challenge := strings.ToLower(resp.Header.Get("Cf-Mitigated"))
	lowerBody := strings.ToLower(body)

	return strings.Contains(server, "cloudflare") ||
		strings.Contains(contentType, "text/html") ||
		strings.Contains(challenge, "challenge") ||
		strings.Contains(lowerBody, "cloudflare") ||
		strings.Contains(lowerBody, "cf-browser-verification") ||
		strings.Contains(lowerBody, "attention required")
}

func (m *TokenManager) coolingDurationForToken(token *store.Token) time.Duration {
	if token == nil || m.cfg == nil {
		return minCoolingDuration
	}
	var duration time.Duration
	switch token.Pool {
	case PoolSuper:
		duration = time.Duration(m.cfg.SuperCoolDurationMin) * time.Minute
	default:
		duration = time.Duration(m.cfg.BasicCoolDurationMin) * time.Minute
	}
	if duration < minCoolingDuration {
		return minCoolingDuration
	}
	return duration
}
