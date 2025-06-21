;; Telemedicine Provider Verification Contract
;; Validates and manages telemedicine providers

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_PROVIDER_EXISTS (err u101))
(define-constant ERR_PROVIDER_NOT_FOUND (err u102))
(define-constant ERR_INVALID_STATUS (err u103))

;; Provider status constants
(define-constant STATUS_PENDING u0)
(define-constant STATUS_VERIFIED u1)
(define-constant STATUS_SUSPENDED u2)
(define-constant STATUS_REVOKED u3)

;; Provider data structure
(define-map providers
  { provider-id: principal }
  {
    name: (string-ascii 100),
    specialty: (string-ascii 50),
    license-number: (string-ascii 50),
    status: uint,
    verification-date: uint,
    rating: uint
  }
)

;; Provider verification requests
(define-map verification-requests
  { request-id: uint }
  {
    provider-id: principal,
    submitted-at: uint,
    documents-hash: (string-ascii 64)
  }
)

(define-data-var next-request-id uint u1)

;; Register a new provider
(define-public (register-provider (name (string-ascii 100)) (specialty (string-ascii 50)) (license-number (string-ascii 50)))
  (let ((provider-id tx-sender))
    (asserts! (is-none (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_EXISTS)
    (map-set providers
      { provider-id: provider-id }
      {
        name: name,
        specialty: specialty,
        license-number: license-number,
        status: STATUS_PENDING,
        verification-date: u0,
        rating: u0
      }
    )
    (ok provider-id)
  )
)

;; Submit verification request
(define-public (submit-verification-request (documents-hash (string-ascii 64)))
  (let ((request-id (var-get next-request-id))
        (provider-id tx-sender))
    (asserts! (is-some (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_NOT_FOUND)
    (map-set verification-requests
      { request-id: request-id }
      {
        provider-id: provider-id,
        submitted-at: block-height,
        documents-hash: documents-hash
      }
    )
    (var-set next-request-id (+ request-id u1))
    (ok request-id)
  )
)

;; Verify provider (admin only)
(define-public (verify-provider (provider-id principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? providers { provider-id: provider-id })) ERR_PROVIDER_NOT_FOUND)
    (map-set providers
      { provider-id: provider-id }
      (merge (unwrap-panic (map-get? providers { provider-id: provider-id }))
        { status: STATUS_VERIFIED, verification-date: block-height }
      )
    )
    (ok true)
  )
)

;; Get provider info
(define-read-only (get-provider (provider-id principal))
  (map-get? providers { provider-id: provider-id })
)

;; Check if provider is verified
(define-read-only (is-provider-verified (provider-id principal))
  (match (map-get? providers { provider-id: provider-id })
    provider (is-eq (get status provider) STATUS_VERIFIED)
    false
  )
)
