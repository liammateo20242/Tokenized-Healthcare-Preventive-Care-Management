;; Outcome Measurement Contract
;; Evaluates and tracks prevention effectiveness

(define-constant ERR_UNAUTHORIZED (err u500))
(define-constant ERR_OUTCOME_NOT_FOUND (err u501))
(define-constant ERR_INVALID_SCORE (err u502))
(define-constant ERR_INTERVENTION_NOT_FOUND (err u503))

;; Outcome measurement data structure
(define-map outcome-measurements
  { outcome-id: uint }
  {
    patient-id: uint,
    intervention-id: uint,
    provider-id: uint,
    measurement-type: (string-ascii 100),
    baseline-value: uint,
    current-value: uint,
    improvement-score: int,
    measurement-date: uint,
    notes: (string-ascii 500),
    verified: bool
  }
)

;; Protocol effectiveness tracking
(define-map protocol-effectiveness
  { protocol-id: uint }
  {
    total-patients: uint,
    successful-outcomes: uint,
    average-improvement: uint,
    total-cost: uint,
    effectiveness-score: uint
  }
)

;; Patient outcome summary
(define-map patient-outcomes
  { patient-id: uint }
  {
    total-measurements: uint,
    positive-outcomes: uint,
    average-improvement: uint,
    last-measurement-date: uint
  }
)

(define-data-var outcome-counter uint u0)

;; Record outcome measurement
(define-public (record-outcome
  (patient-id uint)
  (intervention-id uint)
  (provider-id uint)
  (measurement-type (string-ascii 100))
  (baseline-value uint)
  (current-value uint)
  (notes (string-ascii 500)))
  (let ((outcome-id (+ (var-get outcome-counter) u1))
        (improvement-score (- (to-int current-value) (to-int baseline-value))))

    (map-set outcome-measurements
      { outcome-id: outcome-id }
      {
        patient-id: patient-id,
        intervention-id: intervention-id,
        provider-id: provider-id,
        measurement-type: measurement-type,
        baseline-value: baseline-value,
        current-value: current-value,
        improvement-score: improvement-score,
        measurement-date: block-height,
        notes: notes,
        verified: false
      }
    )

    ;; Update patient outcome summary
    (let ((current-summary (default-to
      { total-measurements: u0, positive-outcomes: u0, average-improvement: u0, last-measurement-date: u0 }
      (map-get? patient-outcomes { patient-id: patient-id }))))
      (map-set patient-outcomes
        { patient-id: patient-id }
        {
          total-measurements: (+ (get total-measurements current-summary) u1),
          positive-outcomes: (if (> improvement-score 0)
            (+ (get positive-outcomes current-summary) u1)
            (get positive-outcomes current-summary)),
          average-improvement: (get average-improvement current-summary), ;; Simplified for now
          last-measurement-date: block-height
        }
      )
    )

    (var-set outcome-counter outcome-id)
    (ok outcome-id)
  )
)

;; Verify outcome measurement
(define-public (verify-outcome (outcome-id uint) (verified bool))
  (let ((outcome-data (unwrap! (map-get? outcome-measurements { outcome-id: outcome-id }) ERR_OUTCOME_NOT_FOUND)))

    (map-set outcome-measurements
      { outcome-id: outcome-id }
      (merge outcome-data { verified: verified })
    )
    (ok true)
  )
)

;; Calculate protocol effectiveness
(define-public (update-protocol-effectiveness (protocol-id uint))
  (let ((current-effectiveness (default-to
    { total-patients: u0, successful-outcomes: u0, average-improvement: u0, total-cost: u0, effectiveness-score: u0 }
    (map-get? protocol-effectiveness { protocol-id: protocol-id }))))

    ;; This is a simplified calculation - in practice would aggregate from multiple sources
    (map-set protocol-effectiveness
      { protocol-id: protocol-id }
      current-effectiveness
    )
    (ok true)
  )
)

;; Get outcome measurement
(define-read-only (get-outcome (outcome-id uint))
  (map-get? outcome-measurements { outcome-id: outcome-id })
)

;; Get patient outcome summary
(define-read-only (get-patient-outcome-summary (patient-id uint))
  (map-get? patient-outcomes { patient-id: patient-id })
)

;; Get protocol effectiveness
(define-read-only (get-protocol-effectiveness (protocol-id uint))
  (map-get? protocol-effectiveness { protocol-id: protocol-id })
)

;; Calculate improvement percentage
(define-read-only (calculate-improvement-percentage (baseline uint) (current uint))
  (if (is-eq baseline u0)
    0
    (/ (* (- (to-int current) (to-int baseline)) 100) (to-int baseline))
  )
)
