
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