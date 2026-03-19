;; ------------------------------------------------------------
;; NeuroForge.clar
;; NeuroForge Protocol: Decentralized AI Training & Model Economy
;; Version: 2.0.0
;; Author: your-handle
;; ------------------------------------------------------------

;; -----------------------------
;; Fungible Token (NEU)
;; -----------------------------
(define-fungible-token neuro-token u1000000)

;; -----------------------------
;; Data Maps
;; -----------------------------

;; Training pools
(define-map training-pools
  { pool-id: uint }
  { creator: principal, bond: uint, completed: bool }
)

;; Compute contributors
(define-map compute-nodes
  { pool-id: uint, node: principal }
  { compute-power: uint, reward: uint }
)

;; AI model registry
(define-map model-registry
  { model-id: uint }
  { owner: principal, storage-link: (string-ascii 256) }
)

;; -----------------------------
;; Constants & Errors
;; -----------------------------
(define-constant CONTRACT-OWNER tx-sender)

(define-constant ERR-INVALID-ID          (err u100))
(define-constant ERR-INVALID-BOND        (err u101))
(define-constant ERR-POOL-NOT-FOUND      (err u102))
(define-constant ERR-TRANSFER-FAILED     (err u103))
(define-constant ERR-NOT-AUTHORIZED      (err u104))
(define-constant ERR-INVALID-COMPUTE     (err u105))
(define-constant ERR-MINT-FAILED         (err u106))
(define-constant ERR-MODEL-EXISTS        (err u107))
(define-constant ERR-MODEL-NOT-FOUND     (err u108))
(define-constant ERR-NOT-MODEL-OWNER     (err u109))
(define-constant ERR-INVALID-STORAGE     (err u110))
(define-constant ERR-INVALID-RECIPIENT   (err u111))

;; -----------------------------
;; Event Logs
;; -----------------------------
(define-data-var pool-created (tuple (pool-id uint) (creator principal)) {pool-id: u0, creator: tx-sender})
(define-data-var training-finalized (tuple (pool-id uint) (winner principal)) {pool-id: u0, winner: tx-sender})
(define-data-var model-registered (tuple (model-id uint) (owner principal)) {model-id: u0, owner: tx-sender})

;; -----------------------------
;; Create Training Pool
;; -----------------------------
(define-public (create-training-pool (pool-id uint) (bond uint))
  (begin
    (asserts! (> pool-id u0) ERR-INVALID-ID)
    (asserts! (>= bond u100) ERR-INVALID-BOND)

    (match (ft-transfer? neuro-token bond tx-sender CONTRACT-OWNER)
      success
        (begin
          (map-set training-pools { pool-id: pool-id }
            { creator: tx-sender, bond: bond, completed: false })

          (var-set pool-created { pool-id: pool-id, creator: tx-sender })
          (print (var-get pool-created))

          (ok pool-id)
        )
      error ERR-TRANSFER-FAILED
    )
  )
)

;; -----------------------------
;; Contribute Compute
;; -----------------------------
(define-public (contribute-compute (pool-id uint) (compute uint))
  (begin
    (asserts! (> pool-id u0) ERR-INVALID-ID)
    (asserts! (> compute u0) ERR-INVALID-COMPUTE)

    (asserts!
      (is-some (map-get? training-pools { pool-id: pool-id }))
      ERR-POOL-NOT-FOUND
    )

    (map-set compute-nodes
      { pool-id: pool-id, node: tx-sender }
      { compute-power: compute, reward: u0 })

    (ok compute)
  )
)

;; -----------------------------
;; Finalize Training
;; -----------------------------
(define-public (finalize-training (pool-id uint) (winner principal))
  (begin
    (asserts! (> pool-id u0) ERR-INVALID-ID)

    (let ((pool (map-get? training-pools { pool-id: pool-id })))
      (match pool pool-data
        (begin
          (asserts! (is-eq (get creator pool-data) tx-sender) ERR-NOT-AUTHORIZED)
          (asserts! (not (get completed pool-data)) ERR-NOT-AUTHORIZED)

          ;; mark complete
          (map-set training-pools { pool-id: pool-id }
            { creator: tx-sender, bond: u0, completed: true })

          ;; reward winner
          (match (ft-mint? neuro-token u500 winner)
            success
              (begin
                (var-set training-finalized { pool-id: pool-id, winner: winner })
                (print (var-get training-finalized))
                (ok pool-id)
              )
            error ERR-MINT-FAILED
          )
        )
        ERR-POOL-NOT-FOUND
      )
    )
  )
)

;; -----------------------------
;; Register AI Model
;; -----------------------------
(define-public (register-model (model-id uint) (storage-link (string-ascii 256)))
  (begin
    (asserts! (> model-id u0) ERR-INVALID-ID)
    (asserts! (> (len storage-link) u0) ERR-INVALID-STORAGE)

    (asserts!
      (is-none (map-get? model-registry { model-id: model-id }))
      ERR-MODEL-EXISTS
    )

    (map-set model-registry { model-id: model-id }
      { owner: tx-sender, storage-link: storage-link })

    (var-set model-registered { model-id: model-id, owner: tx-sender })
    (print (var-get model-registered))

    (ok model-id)
  )
)

;; -----------------------------
;; Transfer Model Ownership
;; -----------------------------
(define-public (transfer-model (model-id uint) (recipient principal))
  (begin
    (asserts! (> model-id u0) ERR-INVALID-ID)
    (asserts! (not (is-eq recipient tx-sender)) ERR-INVALID-RECIPIENT)

    (let ((model (map-get? model-registry { model-id: model-id })))
      (match model model-data
        (begin
          (asserts!
            (is-eq (get owner model-data) tx-sender)
            ERR-NOT-MODEL-OWNER
          )

          (map-set model-registry { model-id: model-id }
            { owner: recipient, storage-link: (get storage-link model-data) })

          (ok recipient)
        )
        ERR-MODEL-NOT-FOUND
      )
    )
  )
)

;; -----------------------------
;; Read-Only Views
;; -----------------------------
(define-read-only (get-pool (pool-id uint))
  (ok (map-get? training-pools { pool-id: pool-id }))
)

(define-read-only (get-node (pool-id uint) (node principal))
  (ok (map-get? compute-nodes { pool-id: pool-id, node: node }))
)

(define-read-only (get-model (model-id uint))
  (ok (map-get? model-registry { model-id: model-id }))
)