;; Intervention Tracking Contract
;; Tracks preventive interventions and their implementation

(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_INTERVENTION_NOT_FOUND (err u401))
(define-constant ERR_INVALID_STATUS (err u402))
(define-constant ERR_PATIENT_NOT_FOUND (err u403))

;; Intervention status constants
(define-constant STATUS_PLANNED u1)
(define-constant STATUS_IN_PROGRESS u2)
(define-constant STATUS_COMPLETED u3)
(define-constant STATUS_CANCELLED u4)

;; Intervention data structure
(define-map interventions
  { intervention-id: uint }
  {
    patient-id: uint,
    protocol-id: uint,
    provider-id: uint,
    intervention-type: (string-ascii 100),
    description: (string-ascii 500),
    planned-date: uint,
    actual-date: (optional uint),
    status: uint,
    notes: (string-ascii 500),
    cost: uint
  }
)

;; Patient intervention summary
(define-map patient-intervention-summary
  { patient-id: uint }
  {
    total-interventions: uint,
    completed-interventions: uint,
    pending-interventions: uint,
    total-cost: uint
  }
)

(define-data-var intervention-counter uint u0)

;; Create intervention
(define-public (create-intervention
  (patient-id uint)
  (protocol-id uint)
  (provider-id uint)
  (intervention-type (string-ascii 100))
  (description (string-ascii 500))
  (planned-date uint)
  (cost uint))
  (let ((intervention-id (+ (var-get intervention-counter) u1)))

    (map-set interventions
      { intervention-id: intervention-id }
      {
        patient-id: patient-id,
        protocol-id: protocol-id,
        provider-id: provider-id,
        intervention-type: intervention-type,
        description: description,
        planned-date: planned-date,
        actual-date: none,
        status: STATUS_PLANNED,
        notes: "",
        cost: cost
      }
    )

    ;; Update patient summary
    (let ((current-summary (default-to
      { total-interventions: u0, completed-interventions: u0, pending-interventions: u0, total-cost: u0 }
      (map-get? patient-intervention-summary { patient-id: patient-id }))))
      (map-set patient-intervention-summary
        { patient-id: patient-id }
        {
          total-interventions: (+ (get total-interventions current-summary) u1),
          completed-interventions: (get completed-interventions current-summary),
          pending-interventions: (+ (get pending-interventions current-summary) u1),
          total-cost: (+ (get total-cost current-summary) cost)
        }
      )
    )

    (var-set intervention-counter intervention-id)
    (ok intervention-id)
  )
)

;; Update intervention status
(define-public (update-intervention-status
  (intervention-id uint)
  (new-status uint)
  (notes (string-ascii 500)))
  (let ((intervention-data (unwrap! (map-get? interventions { intervention-id: intervention-id }) ERR_INTERVENTION_NOT_FOUND)))
    (asserts! (and (>= new-status STATUS_PLANNED) (<= new-status STATUS_CANCELLED)) ERR_INVALID_STATUS)

    (map-set interventions
      { intervention-id: intervention-id }
      (merge intervention-data {
        status: new-status,
        actual-date: (if (is-eq new-status STATUS_COMPLETED) (some block-height) none),
        notes: notes
      })
    )

    ;; Update patient summary if completed
    (if (is-eq new-status STATUS_COMPLETED)
      (let ((patient-id (get patient-id intervention-data))
            (current-summary (unwrap! (map-get? patient-intervention-summary { patient-id: patient-id }) ERR_PATIENT_NOT_FOUND)))
        (map-set patient-intervention-summary
          { patient-id: patient-id }
          {
            total-interventions: (get total-interventions current-summary),
            completed-interventions: (+ (get completed-interventions current-summary) u1),
            pending-interventions: (- (get pending-interventions current-summary) u1),
            total-cost: (get total-cost current-summary)
          }
        )
        (ok true)
      )
      (ok true)
    )
  )
)

;; Get intervention details
(define-read-only (get-intervention (intervention-id uint))
  (map-get? interventions { intervention-id: intervention-id })
)

;; Get patient intervention summary
(define-read-only (get-patient-summary (patient-id uint))
  (map-get? patient-intervention-summary { patient-id: patient-id })
)

;; Check if intervention is overdue
(define-read-only (is-intervention-overdue (intervention-id uint))
  (match (map-get? interventions { intervention-id: intervention-id })
    intervention-data (and
      (not (is-eq (get status intervention-data) STATUS_COMPLETED))
      (not (is-eq (get status intervention-data) STATUS_CANCELLED))
      (> block-height (get planned-date intervention-data))
    )
    false
  )
)
