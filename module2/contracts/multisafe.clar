
;; multisafe
;; <add a description here>

;; constants
;;

;; data maps and vars
;;

;; private functions
;;

;; public functions
;; add-owner, remove owner, set-threshold, revoke, confirm, submit

;;read-only
;;(get-owners ), get-threshold, get-nonce, get-info, get-txn, get-txns
;; 

;; Errors
(define-constant ERR-CALLER-MUST-BE-SELF (err u100))
(define-constant ERR-OWNER-ALREADY-EXISTS (err u110))
(define-constant ERR-OWNER-NOT-EXISTS (err u120))
(define-constant ERR-AT-LEAST-ONE-OWNER-REQUIRED (err u200))
(define-constant ERR-THRESHOLD-OVERFLOW-OWNERS (err u230))


;; Principal of deployed contract
(define-constant SELF (as-contract tx-sender))

;; The owners list
(define-data-var owners (list 20 principal) (list)) 

;; Returns owner list
;; @returns list
(define-read-only (get-owners)
    (var-get owners)
)

;; Private function to push a new member to the owners list
;; @params owner
;; @returns bool
(define-private (add-owner-internal (owner principal))
    (var-set owners (unwrap-panic (as-max-len? (append (var-get owners) owner) u20)))
)


(define-data-var threshold uint u0)

;; Returns confirmation threshold
;; @returns uint 
(define-read-only (get-threshold)
    (var-get threshold)
)

;; Private function to set confirmation threshold
;; @params value
;; return bool
(define-private (set-threshold-internal (value uint))
    (var-set threshold value)
)


;; Adds new owner
;; @restricted to SELF
;; @params owner
;; @returns (response bool)
(define-public (add-owner (owner principal))
    (begin
        (asserts! (is-eq tx-sender SELF) ERR-CALLER-MUST-BE-SELF)
        (asserts! (is-none (index-of (var-get owners) owner)) ERR-OWNER-ALREADY-EXISTS)
        (ok (add-owner-internal owner))
    )
)

;; A helper variable to filter owners while removing one
(define-data-var rem-owner principal tx-sender)

;; Returns a new owner list removing the given as parameter
;; @param owner
;; @returns list
(define-private (remove-owner-filter (owner principal)) (not (is-eq owner (var-get rem-owner))))


;; Removes an owner
;; @restricted to SELF
;; @params owner
;; @returns (response bool)
(define-public (remove-owner (owner principal))
    (let
        (
            (owners-list (var-get owners))
        )
        (asserts! (is-eq tx-sender SELF) ERR-CALLER-MUST-BE-SELF)
        (asserts! (is-some (index-of owners-list owner)) ERR-OWNER-NOT-EXISTS)
        (asserts! (> (len owners-list) u1) ERR-AT-LEAST-ONE-OWNER-REQUIRED)
        (asserts! (>= (- (len owners-list) u1) (var-get threshold)) ERR-THRESHOLD-OVERFLOW-OWNERS)
        (var-set rem-owner owner)
        (ok (var-set owners (unwrap-panic (as-max-len? (filter remove-owner-filter owners-list) u20))))
    )
)

;; Safe initializer
;; @params o ; owners list
;; @params m ; minimum required confirmation number
(define-private (init (o (list 20 principal)) (m uint))
    (begin
        (map add-owner-internal o)
        (set-threshold-internal m)
        (print {action: "multisafe-init"})
    )
)

(init (list 
    'ST1SJ3DTE5DN7X54YDH5D64R3BCB6A2AG2ZQ8YPD5 
    'ST2CY5V39NHDPWSXMW9QDT3HC3GD6Q6XX4CFRK9AG 
    'ST2JHG361ZXG51QTKY2NQCVBPPRRE2KZB1HR05NNC
) u2) 