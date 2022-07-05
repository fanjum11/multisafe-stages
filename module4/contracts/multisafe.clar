
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
(use-trait executor-trait .traits.executor-trait) 
(use-trait safe-trait .traits.safe-trait)
(use-trait nft-trait .traits.sip-009-trait)
(use-trait ft-trait .traits.sip-010-trait)

(impl-trait .traits.safe-trait)

;; Errors
(define-constant ERR-CALLER-MUST-BE-SELF (err u100))
(define-constant ERR-OWNER-ALREADY-EXISTS (err u110))
(define-constant ERR-OWNER-NOT-EXISTS (err u120))
(define-constant ERR-UNAUTHORIZED-SENDER (err u130))
(define-constant ERR-TX-NOT-FOUND (err u140))
(define-constant ERR-TX-ALREADY-CONFIRMED-BY-OWNER (err u150))
(define-constant ERR-TX-INVALID-EXECUTOR (err u160))
(define-constant ERR-INVALID-SAFE (err u170))
(define-constant ERR-TX-CONFIRMED (err u180))
(define-constant ERR-TX-NOT-CONFIRMED-BY-SENDER (err u190))
(define-constant ERR-AT-LEAST-ONE-OWNER-REQUIRED (err u200))
(define-constant ERR-THRESHOLD-CANT-BE-ZERO (err u210))
(define-constant ERR-THRESHOLD-OVERFLOW (err u220))
(define-constant ERR-THRESHOLD-OVERFLOW-OWNERS (err u230))
(define-constant ERR-TX-INVALID-FT (err u240))
(define-constant ERR-TX-INVALID-NFT (err u250))


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

;; Updates minimum confirmation threshold
;; @restricted to SELF
;; @params value
;; @returns (response bool)
(define-public (set-threshold (value uint))
    (begin
        (asserts! (is-eq tx-sender SELF) ERR-CALLER-MUST-BE-SELF)
        (asserts! (> value u0) ERR-THRESHOLD-CANT-BE-ZERO)
        (asserts! (<= value u20) ERR-THRESHOLD-OVERFLOW)
        (asserts! (<= value (len (var-get owners))) ERR-THRESHOLD-OVERFLOW-OWNERS)
        (ok (set-threshold-internal value))
    )
)

;; A helper variable to filter confirmations while removing one
(define-data-var rem-confirmation principal tx-sender)


;; Returns a new confirmations list removing the given as parameter
;; @param owner
;; @returns list
(define-private (remove-confirmation-filter (owner principal)) (not (is-eq owner (var-get rem-confirmation))))

(define-map transactions 
    uint 
    {
        executor: principal,
        threshold: uint,
        confirmations: (list 20 principal),
        confirmed: bool,
        param-ft: principal,
        param-nft: principal,
        param-p: (optional principal),
        param-u: (optional uint),
        param-b: (optional (buff 20))
    }
)

;; Allows an owner to remove their confirmation on the transaction
;; @restricted to owner who confirmed the transaction before
;; @params tx-id ; transaction id
;; @returns (response bool)
(define-public (revoke (tx-id uint))
    (let 
        (
            (tx (unwrap! (map-get? transactions tx-id) ERR-TX-NOT-FOUND))
            (confirmations (get confirmations tx))
        )
        (asserts! (is-eq (get confirmed tx) false) ERR-TX-CONFIRMED)
        (asserts! (is-some (index-of confirmations tx-sender)) ERR-TX-NOT-CONFIRMED-BY-SENDER)
        (var-set rem-confirmation tx-sender)
        (let 
            (
                (new-confirmations  (unwrap-panic (as-max-len? (filter remove-confirmation-filter confirmations) u20)))
                (new-tx (merge tx {confirmations: new-confirmations}))
            )
            (map-set transactions tx-id new-tx)
            (print {action: "multisafe-revoke", sender: tx-sender, tx-id: tx-id})
            (ok true)
        )
    )
)

;; Allows an owner to confirm a tranaction. If the transaction reaches sufficient confirmation number 
;; then the executor specified on the transaction gets triggered.
;; @restricted to owners who hasn't confirmed the transaction yet
;; @params executor ; contract address to be executed
;; @params safe ; address of safe instance / SELF
;; @params param-ft ; fungible token reference for token transfers
;; @params param-nft ; non-fungible token reference for token transfers
;; @returns (response bool)
(define-public (confirm (tx-id uint) (executor <executor-trait>) (safe <safe-trait>) (param-ft <ft-trait>) (param-nft <nft-trait>))
    (begin
        (asserts! (is-some (index-of (var-get owners) tx-sender)) ERR-UNAUTHORIZED-SENDER)
        (asserts! (is-eq (contract-of safe) SELF) ERR-INVALID-SAFE) 
        (let
            (
                (tx (unwrap! (map-get? transactions tx-id) ERR-TX-NOT-FOUND))
                (confirmations (get confirmations tx))
            )

            (asserts! (is-eq (get confirmed tx) false) ERR-TX-CONFIRMED)
            (asserts! (is-none (index-of confirmations tx-sender)) ERR-TX-ALREADY-CONFIRMED-BY-OWNER)
            (asserts! (is-eq (get executor tx) (contract-of executor)) ERR-TX-INVALID-EXECUTOR)
            (asserts! (is-eq (get param-ft tx) (contract-of param-ft)) ERR-TX-INVALID-FT)
            (asserts! (is-eq (get param-nft tx) (contract-of param-nft)) ERR-TX-INVALID-NFT)
            
            (let 
                (
                    (new-confirmations (unwrap-panic (as-max-len? (append confirmations tx-sender) u20)))
                    (confirmed (>= (len new-confirmations) (get threshold tx)))
                    (new-tx (merge tx {confirmations: new-confirmations, confirmed: confirmed}))
                )
                (map-set transactions tx-id new-tx)
                (and confirmed (try! (as-contract (contract-call? executor execute safe param-ft param-nft (get param-p tx) (get param-u tx) (get param-b tx)))))
                (print {action: "multisafe-confirmation", sender: tx-sender, tx-id: tx-id, confirmed: confirmed})
                (ok confirmed)
            )
        )
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