;; Quality Assurance Contract
;; Ensures telemedicine service quality

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_METRIC_NOT_FOUND (err u401))
(define-constant ERR_INVALID_SCORE (err u402))

;; Quality metrics
(define-map quality-metrics
  { provider-id: principal, metric-type: (string-ascii 50) }
  {
    score: uint,
    total-evaluations: uint,
    last-updated: uint
  }
)

;; Quality standards
(define-map quality-standards
  { metric-type: (string-ascii 50) }
  {
    minimum-score: uint,
    weight: uint,
    description: (string-ascii 200)
  }
)

;; Quality evaluations
(define-map evaluations
  { evaluation-id: uint }
  {
    provider-id: principal,
    evaluator-id: principal,
    consultation-id: uint,
    scores: (list 10 uint),
    comments: (string-ascii 500),
    evaluated-at: uint
  }
)

(define-data-var next-evaluation-id uint u1)

;; Set quality standard
(define-public (set-quality-standard
  (metric-type (string-ascii 50))
  (minimum-score uint)
  (weight uint)
  (description (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (map-set quality-standards
      { metric-type: metric-type }
      {
        minimum-score: minimum-score,
        weight: weight,
        description: description
      }
    )
    (ok true)
  )
)

;; Submit quality evaluation
(define-public (submit-evaluation
  (provider-id principal)
  (consultation-id uint)
  (scores (list 10 uint))
  (comments (string-ascii 500)))
  (let ((evaluation-id (var-get next-evaluation-id))
        (evaluator-id tx-sender))
    (map-set evaluations
      { evaluation-id: evaluation-id }
      {
        provider-id: provider-id,
        evaluator-id: evaluator-id,
        consultation-id: consultation-id,
        scores: scores,
        comments: comments,
        evaluated-at: block-height
      }
    )
    (var-set next-evaluation-id (+ evaluation-id u1))
    (ok evaluation-id)
  )
)

;; Update quality metric
(define-public (update-quality-metric
  (provider-id principal)
  (metric-type (string-ascii 50))
  (new-score uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_UNAUTHORIZED)
    (asserts! (<= new-score u100) ERR_INVALID_SCORE)
    (let ((current-metric (default-to
                            { score: u0, total-evaluations: u0, last-updated: u0 }
                            (map-get? quality-metrics { provider-id: provider-id, metric-type: metric-type }))))
      (map-set quality-metrics
        { provider-id: provider-id, metric-type: metric-type }
        {
          score: new-score,
          total-evaluations: (+ (get total-evaluations current-metric) u1),
          last-updated: block-height
        }
      )
    )
    (ok true)
  )
)

;; Get quality metric
(define-read-only (get-quality-metric (provider-id principal) (metric-type (string-ascii 50)))
  (map-get? quality-metrics { provider-id: provider-id, metric-type: metric-type })
)

;; Get quality standard
(define-read-only (get-quality-standard (metric-type (string-ascii 50)))
  (map-get? quality-standards { metric-type: metric-type })
)

;; Check if provider meets quality standards
(define-read-only (meets-quality-standards (provider-id principal) (metric-type (string-ascii 50)))
  (match (map-get? quality-metrics { provider-id: provider-id, metric-type: metric-type })
    metric (match (map-get? quality-standards { metric-type: metric-type })
             standard (>= (get score metric) (get minimum-score standard))
             false)
    false
  )
)
