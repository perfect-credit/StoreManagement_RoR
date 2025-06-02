# Shopify Backend Challenge - Order Delivery Date Service

## Quick Start

### Prerequisites
- Ruby 3.4.4
- Rails 7.x
- Docker (optional)

### Project Setup

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd shopify-backend-challenge
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   ```
   Edit `.env` file with your Shopify credentials:
   ```bash
   SHOPIFY_API_KEY=your-api-key
   SHOPIFY_API_SECRET=your-api-secret
   SHOPIFY_ACCESS_TOKEN=your-access-token
   SHOPIFY_SHOP_NAME=your-shop-name
   APP_HOST=your-host-name
   ```
### Running the Application

#### Option 1: Local Development
1. Start the Rails server:
   ```bash
   rails server
   ```
2. Visit http://localhost:3000

#### Option 2: Using Docker
1. Build and start the containers:
   ```bash
   docker-compose up --build
   ```
2. Visit http://localhost:3000

## Overview
This project implements a service to manage and track estimated delivery dates for Shopify orders. The service processes orders, retrieves product-specific delivery estimates, and stores this information as metafields in Shopify, making it accessible throughout the platform.

## Features
- Batch processing of Shopify orders
- Retrieval of product-specific delivery dates
- JSON file generation for delivery information
- Automatic metafield attachment to orders
- Error handling and logging
- Scalable processing with configurable batch sizes

## Technical Implementation

### Core Components

#### OrderDeliveryDateService
The main service class that handles:
- Order validation and processing
- Delivery date collection for line items
- JSON file generation and upload
- Metafield attachment to orders

### Design Patterns
- **Service Object Pattern**: Encapsulates business logic in a dedicated service class
- **Batch Processing**: Handles orders in configurable batches for better performance
- **Error Handling**: Comprehensive error catching and logging
- **Dependency Injection**: Flexible initialization with order data

### Data Flow
1. Orders are processed in batches
2. Each order's line items are analyzed
3. Delivery dates are collected for each product
4. Data is compiled into a JSON file
5. File is uploaded to Shopify
6. Metafield is attached to the order with file reference

## Configuration

### Constants
- `METAFIELD_NAMESPACE`: "max_mustermann"
- `METAFIELD_DELIVERY_KEY`: "estimated_delivery"
- `METAFIELD_FILE_KEY`: "delivery_dates"
- `BATCH_SIZE`: 50 orders per batch

## Error Handling
- Comprehensive error handling at both batch and individual order level
- Detailed logging for debugging and monitoring
- Custom `ShopifyError` class for service-specific exceptions

## Assumptions
1. Product delivery dates are stored as metafields on products
2. All orders contain valid line items with product IDs
3. The application has necessary Shopify API permissions
4. Ruby on Rails environment with required dependencies

## Dependencies
- Ruby on Rails
- Shopify API integration
- JSON processing capabilities

## Best Practices
- Detailed logging for monitoring and debugging
- Batch processing for performance optimization
- Error isolation to prevent batch failures
- Clean separation of concerns
- Consistent metafield naming conventions

## Usage Example
```ruby
# Process a batch of orders
orders = [...] # Array of order data
OrderDeliveryDateService.process_batch(orders)

# Process single order
service = OrderDeliveryDateService.new(order_data)
service.process
```

## Notes
- The service is designed to be idempotent
- Failed orders won't affect the processing of other orders in the batch
- All operations are logged for monitoring and debugging
- The service can be extended to handle additional delivery date logic

## Testing Setup

### 1. Product Synchronization
1. Configure environment variables:
   ```bash
   SHOPIFY_API_KEY=your-api-key
   SHOPIFY_API_SECRET=your-api-secret
   SHOPIFY_ACCESS_TOKEN=your-access-token
   SHOPIFY_SHOP_NAME=your-shop-name
   APP_HOST=your-host-name
   ```
2. Run the product sync task:
   ```bash
   rails sync:products
   ```
   This will synchronize your Shopify products with the application.

### 2. Order Synchronization
1. Install and run ngrok:
   ```bash
   ngrok http 3000
   ```

2. Update your environment variables with the ngrok URL:
   ```bash
   APP_HOST=your-ngrok-url
   ```

3. Subscribe to Shopify webhooks:
   ```bash
   rails webhooks:subscribe
   ```
   This sets up the necessary webhooks for order processing.

4. Start the Rails server:
   ```bash
   rails server
   ```

5. Test the flow:
   - Go to your Shopify store
   - Purchase a product
   - The order will be automatically processed by the service
   - Check the logs for processing details

### Monitoring
- Monitor the Rails logs for processing status and any errors
- Check the Shopify admin panel to verify metafield attachments
- Verify JSON file uploads in Shopify Files section

## Notes
- The service is designed to be idempotent
- Failed orders won't affect the processing of other orders in the batch
- All operations are logged for monitoring and debugging
- The service can be extended to handle additional delivery date logic

## Docker Setup

### Building and Running with Docker

1. Build the Docker image:
   ```bash
   docker build -t shopify-backend-challenge .
   ```

2. Run the container:
   ```bash
   docker run -p 3000:3000 \
   -e SHOPIFY_API_KEY=your-api-key \
   -e SHOPIFY_API_SECRET=your-api-secret \
   -e SHOPIFY_ACCESS_TOKEN=your-access-token \
   -e SHOPIFY_SHOP_NAME=your-shop-name \
   -e APP_HOST=your-host-name \
   shopify-backend-challenge
   ```

### Using Docker Compose

Create a `docker-compose.yml` file in your project root:

```yaml
version: '3'
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - SHOPIFY_API_KEY=${SHOPIFY_API_KEY}
      - SHOPIFY_API_SECRET=${SHOPIFY_API_SECRET}
      - SHOPIFY_ACCESS_TOKEN=${SHOPIFY_ACCESS_TOKEN}
      - SHOPIFY_SHOP_NAME=${SHOPIFY_SHOP_NAME}
      - APP_HOST=${APP_HOST}
    volumes:
      - .:/app
```

Then run:
```bash
docker-compose up
```

### Docker Development Tips
- Use `docker-compose up --build` to rebuild the image when dependencies change
- Access the container shell: `docker-compose exec web bash`
- View logs: `docker-compose logs -f web`
