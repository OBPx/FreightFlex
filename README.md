# FreightFlex

FreightFlex is a decentralized marketplace on the Stacks blockchain that enables dynamic pricing for unutilized freight capacity. The platform connects carriers with available capacity to shippers needing transportation services.

## Overview

In the transportation and logistics industry, unused capacity represents lost revenue for carriers. Meanwhile, shippers often struggle to find available freight options at reasonable prices, especially during peak seasons. FreightFlex solves this problem by creating a transparent marketplace with dynamic pricing based on real-time demand and proximity to departure.

## Features

- **Carrier Management**: Register logistics providers and maintain reputation scores
- **Freight Listings**: Create and manage listings for available freight capacity
- **Dynamic Pricing**: Adjust prices based on demand and time until departure
- **Secure Booking**: Process bookings with automatic STX payments
- **Status Tracking**: Track shipments through their lifecycle
- **Dispute Resolution**: Handle disagreements between carriers and shippers

## Smart Contract

The FreightFlex smart contract is written in Clarity, the secure and predictable smart contract language for the Stacks blockchain. The contract implements:

- Data maps for carriers, freight listings, and bookings
- Authorization checks to ensure only appropriate parties can perform actions
- Fee distribution between carriers and the platform
- Status management for freight shipments

## Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Basic understanding of Stacks and Clarity

### Installation

1. Clone this repository
   ```
   git clone https://github.com/yourusername/freightflex.git
   cd freightflex
   ```

2. Test the contract using Clarinet
   ```
   clarinet check
   clarinet test
   ```

### Usage

#### For Carriers:

1. Register as a carrier
2. Create freight listings with available capacity
3. Update prices dynamically as needed
4. Track and update shipment statuses

#### For Shippers:

1. View available freight capacity
2. Book capacity with STX payment
3. Track shipment status
4. File disputes if necessary

## Contract Functions

### Administration
- `set-platform-fee`: Update the platform fee percentage
- `set-admin`: Transfer admin rights to a new address

### Carrier Management
- `register-carrier`: Register as a new carrier
- `update-carrier-reputation`: Update a carrier's reputation score
- `get-carrier`: View carrier details

### Freight Listings
- `create-freight-listing`: Create a new freight capacity listing
- `update-dynamic-price`: Update the price of a listing
- `cancel-listing`: Cancel an active listing
- `get-freight-listing`: View listing details

### Bookings
- `book-freight`: Book available freight capacity
- `update-shipping-status`: Update the status of a shipment
- `file-dispute`: File a dispute for a booking
- `get-booking`: View booking details

## Roadmap

- [ ] Add multi-leg shipment support
- [ ] Implement a reputation-based pricing algorithm
- [ ] Develop a front-end interface
- [ ] Add support for multiple currencies
- [ ] Integrate with real-world logistics APIs

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Stacks Foundation
- Clarity language documentation
- The global logistics community for inspiration