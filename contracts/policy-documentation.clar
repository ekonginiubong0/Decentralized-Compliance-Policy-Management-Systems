;; Policy Documentation Contract
;; Documents compliance policies

(define-map policies uint {
  title: (string-ascii 100),
  description: (string-ascii 500),
  version: uint,
  created-by: principal,
  created-at: uint,
  active: bool
})

(define-data-var policy-counter uint u0)
(define-data-var contract-owner principal tx-sender)

;; Create a new policy
(define-public (create-policy (title (string-ascii 100)) (description (string-ascii 500)))
  (let ((policy-id (+ (var-get policy-counter) u1)))
    (begin
      (var-set policy-counter policy-id)
      (map-set policies policy-id {
        title: title,
        description: description,
        version: u1,
        created-by: tx-sender,
        created-at: block-height,
        active: true
      })
      (ok policy-id)
    )
  )
)

;; Update policy status
(define-public (update-policy-status (policy-id uint) (active bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) (err u1))
    (asserts! (is-some (map-get? policies policy-id)) (err u2))
    (map-set policies policy-id
      (merge (unwrap-panic (map-get? policies policy-id)) {active: active}))
    (ok true)
  )
)

;; Get policy details
(define-read-only (get-policy (policy-id uint))
  (map-get? policies policy-id)
)

;; Get total policies count
(define-read-only (get-policy-count)
  (var-get policy-counter)
)
