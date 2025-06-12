;; Compliance Monitoring Contract
;; Monitors policy compliance and tracks violations

(define-constant ERR_NOT_AUTHORIZED (err u500))
(define-constant ERR_VIOLATION_NOT_FOUND (err u501))
(define-constant ERR_INVALID_STATUS (err u502))

;; Violation severity levels
(define-constant SEVERITY_LOW u1)
(define-constant SEVERITY_MEDIUM u2)
(define-constant SEVERITY_HIGH u3)
(define-constant SEVERITY_CRITICAL u4)

;; Violation statuses
(define-constant STATUS_OPEN u1)
(define-constant STATUS_INVESTIGATING u2)
(define-constant STATUS_RESOLVED u3)
(define-constant STATUS_CLOSED u4)

;; Data structures
(define-map compliance-violations uint {
    policy-id: uint,
    violator: principal,
    reporter: principal,
    description: (string-ascii 500),
    severity: uint,
    status: uint,
    reported-at: uint,
    resolved-at: (optional uint)
})

(define-map user-compliance-score principal {
    total-violations: uint,
    resolved-violations: uint,
    compliance-score: uint,
    last-updated: uint
})

(define-data-var next-violation-id uint u1)

;; Report compliance violation
(define-public (report-violation
    (policy-id uint)
    (violator principal)
    (description (string-ascii 500))
    (severity uint)
)
    (let ((violation-id (var-get next-violation-id)))
        (asserts! (contract-call? .policy-manager-verification is-verified-manager tx-sender) ERR_NOT_AUTHORIZED)
        (asserts! (<= severity SEVERITY_CRITICAL) ERR_INVALID_STATUS)
        (map-set compliance-violations violation-id {
            policy-id: policy-id,
            violator: violator,
            reporter: tx-sender,
            description: description,
            severity: severity,
            status: STATUS_OPEN,
            reported-at: block-height,
            resolved-at: none
        })
        (var-set next-violation-id (+ violation-id u1))
        (update-compliance-score violator)
        (ok violation-id)
    )
)

;; Update violation status
(define-public (update-violation-status (violation-id uint) (new-status uint))
    (match (map-get? compliance-violations violation-id)
        violation (begin
            (asserts! (contract-call? .policy-manager-verification is-verified-manager tx-sender) ERR_NOT_AUTHORIZED)
            (asserts! (<= new-status STATUS_CLOSED) ERR_INVALID_STATUS)
            (map-set compliance-violations violation-id (merge violation {
                status: new-status,
                resolved-at: (if (>= new-status STATUS_RESOLVED) (some block-height) none)
            }))
            (if (>= new-status STATUS_RESOLVED)
                (update-compliance-score (get violator violation))
                (ok true)
            )
        )
        ERR_VIOLATION_NOT_FOUND
    )
)

;; Update user compliance score
(define-private (update-compliance-score (user principal))
    (let ((current-score (default-to { total-violations: u0, resolved-violations: u0, compliance-score: u100, last-updated: u0 }
                                    (map-get? user-compliance-score user))))
        (map-set user-compliance-score user (merge current-score {
            total-violations: (+ (get total-violations current-score) u1),
            last-updated: block-height
        }))
        (ok true)
    )
)

;; Get violation details
(define-read-only (get-violation (violation-id uint))
    (map-get? compliance-violations violation-id)
)

;; Get user compliance score
(define-read-only (get-compliance-score (user principal))
    (map-get? user-compliance-score user)
)

;; Calculate compliance percentage
(define-read-only (calculate-compliance-percentage (user principal))
    (match (map-get? user-compliance-score user)
        score (let ((total (get total-violations score))
                   (resolved (get resolved-violations score)))
                (if (is-eq total u0)
                    u100
                    (/ (* resolved u100) total)
                )
              )
        u100
    )
)
