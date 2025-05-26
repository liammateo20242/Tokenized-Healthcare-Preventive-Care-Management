;; Patient Risk Assessment Contract
;; Manages patient health risk assessments

(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PATIENT_NOT_FOUND (err u201))
(define-constant ERR_INVALID_RISK_SCORE (err u202))
(define-constant ERR_ASSESSMENT_EXISTS (err u203))

;; Risk assessment data structure
(define-map risk-assessments
  { patient-id: uint, assessment-id: uint }
  {
    provider-id: uint,
    risk-score: uint,
    risk-factors: (list 10 (string-ascii 50)),
    assessment-date: uint,
    next-assessment-due: uint,
    notes: (string-ascii 500)
  }
)

;; Patient risk summary
(define-map patient-risk-summary
  { patient-id: uint }
  {
    current-risk-level: uint,
    last-assessment-date: uint,
    total-assessments: uint
  }
)

(define-data-var assessment-counter uint u0)

;; Create risk assessment
(define-public (create-risk-assessment
  (patient-id uint)
  (provider-id uint)
  (risk-score uint)
  (risk-factors (list 10 (string-ascii 50)))
  (notes (string-ascii 500)))
  (let ((assessment-id (+ (var-get assessment-counter) u1)))
    (asserts! (and (>= risk-score u0) (<= risk-score u100)) ERR_INVALID_RISK_SCORE)

    ;; Create assessment record
    (map-set risk-assessments
      { patient-id: patient-id, assessment-id: assessment-id }
      {
        provider-id: provider-id,
        risk-score: risk-score,
        risk-factors: risk-factors,
        assessment-date: block-height,
        next-assessment-due: (+ block-height u8760), ;; ~6 months in blocks
        notes: notes
      }
    )

    ;; Update patient summary
    (let ((current-summary (default-to
      { current-risk-level: u0, last-assessment-date: u0, total-assessments: u0 }
      (map-get? patient-risk-summary { patient-id: patient-id }))))
      (map-set patient-risk-summary
        { patient-id: patient-id }
        {
          current-risk-level: risk-score,
          last-assessment-date: block-height,
          total-assessments: (+ (get total-assessments current-summary) u1)
        }
      )
    )

    (var-set assessment-counter assessment-id)
    (ok assessment-id)
  )
)

;; Get patient risk level
(define-read-only (get-patient-risk-level (patient-id uint))
  (match (map-get? patient-risk-summary { patient-id: patient-id })
    summary (get current-risk-level summary)
    u0
  )
)

;; Get risk assessment
(define-read-only (get-risk-assessment (patient-id uint) (assessment-id uint))
  (map-get? risk-assessments { patient-id: patient-id, assessment-id: assessment-id })
)

;; Check if assessment is due
(define-read-only (is-assessment-due (patient-id uint))
  (match (map-get? patient-risk-summary { patient-id: patient-id })
    summary (> block-height (+ (get last-assessment-date summary) u8760))
    true
  )
)
