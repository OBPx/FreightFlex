;; FreightFlex - Dynamic Pricing Marketplace for Unutilized Freight Capacity
;; Version: 1.1

;; Define data structures
(define-map carriers 
  { carrier-id: uint }
  {
    name: (string-ascii 64),
    reputation-score: uint,
    active: bool,
    stx-address: principal
  }
)

(define-map freight-listings
  { listing-id: uint }
  {
    carrier-id: uint,
    origin: (string-ascii 64),
    destination: (string-ascii 64),
    capacity-kg: uint,
    volume-cubic-m: uint,
    departure-time: uint,
    arrival-time: uint,
    base-price-ustx: uint,
    current-price-ustx: uint,
    booking-deadline: uint,
    status: (string-ascii 16) ;; "active", "booked", "completed", "cancelled"
  }
)

(define-map bookings
  { booking-id: uint }
  {
    listing-id: uint,
    shipper: principal,
    price-paid-ustx: uint,
    booking-time: uint,
    cargo-description: (string-ascii 256),
    status: (string-ascii 16) ;; "confirmed", "in-transit", "delivered", "disputed"
  }
)

;; Contract variables
(define-data-var last-carrier-id uint u0)
(define-data-var last-listing-id uint u0)
(define-data-var last-booking-id uint u0)
(define-data-var platform-fee-percent uint u5) ;; 5% default platform fee
(define-data-var admin principal tx-sender)
(define-data-var current-time uint u0) ;; Simulated time for testing

;; Constants for validation
(define-constant MAX-TIME u9999999999)
(define-constant MIN-CAPACITY u1)
(define-constant MAX-CAPACITY u100000)
(define-constant MIN-VOLUME u1)
(define-constant MAX-VOLUME u100000)
(define-constant MIN-PRICE u1)
(define-constant MAX-PRICE u1000000000000)
(define-constant VALID-STATUSES (list 
  "active"
  "booked"
  "completed"
  "cancelled"
))
(define-constant VALID-BOOKING-STATUSES (list 
  "confirmed"
  "in-transit"
  "delivered"
  "disputed"
))

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-STATUS (err u422))
(define-constant ERR-INSUFFICIENT-FUNDS (err u402))
(define-constant ERR-PAST-DEADLINE (err u410))
(define-constant ERR-INVALID-PARAMETERS (err u400))
(define-constant ERR-MAX-FEE (err u403))

;; Helper functions for validation
(define-private (is-valid-time (time uint))
  (and (>= time u0) (<= time MAX-TIME))
)

(define-private (is-valid-capacity (capacity uint))
  (and (>= capacity MIN-CAPACITY) (<= capacity MAX-CAPACITY))
)

(define-private (is-valid-volume (volume uint))
  (and (>= volume MIN-VOLUME) (<= volume MAX-VOLUME))
)

(define-private (is-valid-price (price uint))
  (and (>= price MIN-PRICE) (<= price MAX-PRICE))
)

(define-private (is-valid-status (status (string-ascii 16)))
  (not (is-none (index-of VALID-STATUSES status)))
)

(define-private (is-valid-booking-status (status (string-ascii 16)))
  (not (is-none (index-of VALID-BOOKING-STATUSES status)))
)

;; Time management (for testing)
(define-public (set-current-time (new-time uint))
  (begin
    (asserts! (is-valid-time new-time) ERR-INVALID-PARAMETERS)
    (ok (var-set current-time new-time))
  )
)

(define-read-only (get-current-time)
  (var-get current-time)
)

;; Administrative functions
(define-public (set-platform-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u20) ERR-MAX-FEE) ;; Max 20% fee
    (ok (var-set platform-fee-percent new-fee))
  )
)

(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq new-admin tx-sender)) ERR-INVALID-PARAMETERS) ;; Prevent setting to current admin
    (ok (var-set admin new-admin))
  )
)

;; Carrier management
(define-public (register-carrier (name (string-ascii 64)))
  (let
    (
      (carrier-id (+ (var-get last-carrier-id) u1))
      (existing-carrier (map-get? carriers { carrier-id: carrier-id }))
    )
    (asserts! (> (len name) u0) ERR-INVALID-PARAMETERS) ;; Ensure name is not empty
    (asserts! (or (is-none existing-carrier) 
                  (not (get active (default-to { active: false, name: "", reputation-score: u0, stx-address: tx-sender } existing-carrier))))
              ERR-ALREADY-EXISTS)

    ;; Validated name is used here
    (map-set carriers
      { carrier-id: carrier-id }
      {
        name: name,
        reputation-score: u0,
        active: true,
        stx-address: tx-sender
      }
    )
    (var-set last-carrier-id carrier-id)
    (ok carrier-id)
  )
)

(define-read-only (get-carrier (carrier-id uint))
  (map-get? carriers { carrier-id: carrier-id })
)

(define-public (update-carrier-reputation (carrier-id uint) (score uint))
  (let
    (
      (carrier (map-get? carriers { carrier-id: carrier-id }))
    )
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (is-some carrier) ERR-NOT-FOUND)
    (asserts! (<= score u100) ERR-INVALID-PARAMETERS) ;; Score must be between 0-100
    (asserts! (> carrier-id u0) ERR-INVALID-PARAMETERS) ;; Ensure carrier-id is valid

    ;; Validated carrier-id and score are used here
    (map-set carriers
      { carrier-id: carrier-id }
      (merge (unwrap-panic carrier)
             { reputation-score: score })
    )
    (ok true)
  )
)

;; Freight listing management
(define-public (create-freight-listing
  (carrier-id uint)
  (origin (string-ascii 64))
  (destination (string-ascii 64))
  (capacity-kg uint)
  (volume-cubic-m uint)
  (departure-time uint)
  (arrival-time uint)
  (base-price-ustx uint)
  (booking-deadline uint)
)
  (let
    (
      (listing-id (+ (var-get last-listing-id) u1))
      (carrier (map-get? carriers { carrier-id: carrier-id }))
    )
    ;; Validate all parameters
    (asserts! (> carrier-id u0) ERR-INVALID-PARAMETERS)
    (asserts! (> (len origin) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> (len destination) u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-capacity capacity-kg) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-volume volume-cubic-m) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-time departure-time) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-time arrival-time) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-price base-price-ustx) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-time booking-deadline) ERR-INVALID-PARAMETERS)

    ;; Check if carrier exists and is active
    (asserts! (is-some carrier) ERR-NOT-FOUND)
    (asserts! (get active (unwrap-panic carrier)) ERR-INVALID-STATUS)
    ;; Check if the caller is the carrier
    (asserts! (is-eq tx-sender (get stx-address (unwrap-panic carrier))) ERR-NOT-AUTHORIZED)
    ;; Check if valid times
    (asserts! (> departure-time booking-deadline) ERR-INVALID-PARAMETERS)
    (asserts! (> arrival-time departure-time) ERR-INVALID-PARAMETERS)

    ;; Create listing with validated parameters
    (map-set freight-listings
      { listing-id: listing-id }
      {
        carrier-id: carrier-id,
        origin: origin,
        destination: destination,
        capacity-kg: capacity-kg,
        volume-cubic-m: volume-cubic-m,
        departure-time: departure-time,
        arrival-time: arrival-time,
        base-price-ustx: base-price-ustx,
        current-price-ustx: base-price-ustx, ;; Initial price is the base price
        booking-deadline: booking-deadline,
        status: "active"
      }
    )
    (var-set last-listing-id listing-id)
    (ok listing-id)
  )
)

(define-read-only (get-freight-listing (listing-id uint))
  (map-get? freight-listings { listing-id: listing-id })
)

;; Dynamic pricing function
(define-public (update-dynamic-price (listing-id uint) (new-price-ustx uint))
  (let
    (
      (listing (map-get? freight-listings { listing-id: listing-id }))
    )
    (asserts! (> listing-id u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-price new-price-ustx) ERR-INVALID-PARAMETERS)
    (asserts! (is-some listing) ERR-NOT-FOUND)
    (asserts! (is-eq (get status (unwrap-panic listing)) "active") ERR-INVALID-STATUS)

    ;; Check if caller is the carrier
    (let
      (
        (carrier (map-get? carriers { carrier-id: (get carrier-id (unwrap-panic listing)) }))
      )
      (asserts! (is-some carrier) ERR-NOT-FOUND)
      (asserts! (is-eq tx-sender (get stx-address (unwrap-panic carrier))) ERR-NOT-AUTHORIZED)

      ;; Update price with validated parameters
      (map-set freight-listings
        { listing-id: listing-id }
        (merge (unwrap-panic listing)
               { current-price-ustx: new-price-ustx })
      )
      (ok true)
    )
  )
)

;; Booking management
(define-public (book-freight (listing-id uint) (cargo-description (string-ascii 256)))
  (let
    (
      (listing (map-get? freight-listings { listing-id: listing-id }))
      (booking-id (+ (var-get last-booking-id) u1))
      (current-time-value (var-get current-time))
    )
    ;; Validate parameters
    (asserts! (> listing-id u0) ERR-INVALID-PARAMETERS)
    (asserts! (> (len cargo-description) u0) ERR-INVALID-PARAMETERS)

    ;; Check if listing exists and is active
    (asserts! (is-some listing) ERR-NOT-FOUND)
    (asserts! (is-eq (get status (unwrap-panic listing)) "active") ERR-INVALID-STATUS)

    ;; Check if deadline has passed
    (asserts! (< current-time-value (get booking-deadline (unwrap-panic listing))) ERR-PAST-DEADLINE)

    (let
      (
        (price (get current-price-ustx (unwrap-panic listing)))
        (carrier-id (get carrier-id (unwrap-panic listing)))
        (carrier (map-get? carriers { carrier-id: carrier-id }))
        (platform-fee (/ (* price (var-get platform-fee-percent)) u100))
        (carrier-payment (- price platform-fee))
      )
      (asserts! (is-some carrier) ERR-NOT-FOUND)

      ;; Transfer funds from shipper to carrier and platform
      (try! (stx-transfer? carrier-payment tx-sender (get stx-address (unwrap-panic carrier))))
      (try! (stx-transfer? platform-fee tx-sender (var-get admin)))

      ;; Create booking with validated parameters
      (map-set bookings
        { booking-id: booking-id }
        {
          listing-id: listing-id,
          shipper: tx-sender,
          price-paid-ustx: price,
          booking-time: current-time-value,
          cargo-description: cargo-description,
          status: "confirmed"
        }
      )

      ;; Update listing status
      (map-set freight-listings
        { listing-id: listing-id }
        (merge (unwrap-panic listing)
               { status: "booked" })
      )

      (var-set last-booking-id booking-id)
      (ok booking-id)
    )
  )
)

(define-read-only (get-booking (booking-id uint))
  (map-get? bookings { booking-id: booking-id })
)

;; Shipping status management
(define-public (update-shipping-status (booking-id uint) (new-status (string-ascii 16)))
  (let
    (
      (booking (map-get? bookings { booking-id: booking-id }))
    )
    ;; Validate parameters
    (asserts! (> booking-id u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-valid-booking-status new-status) ERR-INVALID-STATUS)
    (asserts! (is-some booking) ERR-NOT-FOUND)

    ;; Check valid status transitions
    (asserts! (or (is-eq new-status "in-transit")
                 (is-eq new-status "delivered")
                 (is-eq new-status "disputed"))
             ERR-INVALID-STATUS)

    ;; Check if caller is the carrier
    (let
      (
        (listing (map-get? freight-listings { listing-id: (get listing-id (unwrap-panic booking)) }))
        (carrier-id (get carrier-id (unwrap-panic listing)))
        (carrier (map-get? carriers { carrier-id: carrier-id }))
      )
      (asserts! (is-some carrier) ERR-NOT-FOUND)
      (asserts! (is-eq tx-sender (get stx-address (unwrap-panic carrier))) ERR-NOT-AUTHORIZED)

      ;; Update status with validated parameters
      (map-set bookings
        { booking-id: booking-id }
        (merge (unwrap-panic booking)
               { status: new-status })
      )

      ;; If delivered, update listing status
      (if (is-eq new-status "delivered")
          (map-set freight-listings
            { listing-id: (get listing-id (unwrap-panic booking)) }
            (merge (unwrap-panic listing)
                   { status: "completed" })
          )
          true
      )

      (ok true)
    )
  )
)

;; Dispute resolution
(define-public (file-dispute (booking-id uint))
  (let
    (
      (booking (map-get? bookings { booking-id: booking-id }))
    )
    ;; Validate parameters
    (asserts! (> booking-id u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-some booking) ERR-NOT-FOUND)
    (asserts! (is-eq tx-sender (get shipper (unwrap-panic booking))) ERR-NOT-AUTHORIZED)

    ;; Update status to disputed with validated parameters
    (map-set bookings
      { booking-id: booking-id }
      (merge (unwrap-panic booking)
             { status: "disputed" })
    )

    (ok true)
  )
)

;; Cancel listing function for carriers
(define-public (cancel-listing (listing-id uint))
  (let
    (
      (listing (map-get? freight-listings { listing-id: listing-id }))
    )
    ;; Validate parameters
    (asserts! (> listing-id u0) ERR-INVALID-PARAMETERS)
    (asserts! (is-some listing) ERR-NOT-FOUND)
    (asserts! (is-eq (get status (unwrap-panic listing)) "active") ERR-INVALID-STATUS)

    ;; Check if caller is the carrier
    (let
      (
        (carrier-id (get carrier-id (unwrap-panic listing)))
        (carrier (map-get? carriers { carrier-id: carrier-id }))
      )
      (asserts! (is-some carrier) ERR-NOT-FOUND)
      (asserts! (is-eq tx-sender (get stx-address (unwrap-panic carrier))) ERR-NOT-AUTHORIZED)

      ;; Update listing status to cancelled with validated parameters
      (map-set freight-listings
        { listing-id: listing-id }
        (merge (unwrap-panic listing)
               { status: "cancelled" })
      )

      (ok true)
    )
  )
)