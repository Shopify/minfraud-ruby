Deprecated: This repository is no longer maintained. It has been archived and receives no updates or security fixes.

# Ruby interface to the MaxMind minFraud API

Compatible with [minFraud](http://www.maxmind.com/en/ccv_overview) Legacy API

[minFraud Legacy API documentation](https://dev.maxmind.com/minfraud/minfraud-legacy/)  

### Example Usage

```ruby
# Create a client to handle requests for a specific host
minfraud_client = Minfraud::MinfraudClient.new(
  # Optional fields to customize connection
  host_choice: 'us_east',
  open_timeout: 1,
  idle_timeout: 5,
  read_timeout: 5,
  write_timeout: 5,
  pool_size: 10
)

# Create a transaction with attributes to send
# The transaction will be immutable after creation
transaction = Minfraud::Transaction.new do |t|
  # Required fields
  t.ip = '1.2.3.4'
  t.txn_id = 'Order-1'
  t.license_key = 'minfraud-license-key'
  # Other fields are optional
  t.city = 'richmond'
  t.state = 'virginia'
  t.postal = '12345'
  t.country = 'US' # http://en.wikipedia.org/wiki/ISO_3166-1
  # ...
end

# Send the transaction to minFraud and retrieve the parsed response
# The response will be immutable
response = minfraud_client.send_transaction(
  transaction: transaction,
  # Optional url to customize the request endpoint
  # Default value is `/app/ccv2r`
  url: '/app/ccv2r'
)

# All attributes from minFraud's response will be available on the response object
# as a snake-cased attribute. For example, if you want the `proxyScore` field
# from minFraud, you can get it with `#proxy_score`.

response.risk_score
# => 3.48

response.queries_remaining
# => 1000

# A warning may be present in the `#err` attribute
response.err
# => nil

# The attributes can also be retrieved as a Hash
# Note that this is a frozen Hash
response_hash = response.body # frozen Hash
response_hash = response.body.dup # mutable duplicate of Hash

response[:risk_score]
response[:queries_remaining]
response[:err]
```

#### Customizing the response

The `Minfraud::Response` is frozen after initialization, but sometimes attributes may need to be added or modified.

This customization can be done via a block on `Minfraud::MinfraudClient#send_transaction`:

```ruby
response = minfraud_client.send_transaction(transaction: transaction) do |resp|
  # resp is the Hash of attributes on the response
  resp[:new_attribute] = some_modification_of(resp[:existing_attribute])
  resp[:another_existing_attribute] = 'new_value'
end
```

### Exception handling

There are three different exceptions that this gem may raise. Please be prepared to handle them:

```ruby
# Raised by Minfraud::Transaction.new if transaction parameters are invalid
class TransactionError < ArgumentError; end

# Raised by Minfraud::MinfraudClient.send_transaction if minFraud returns an error
class ResponseError < StandardError; end

# Raised by Minfraud::MinfraudClient.send_transaction if there was a connection error
class ConnectionException < StandardError; end
```

### Warnings

If there was a warning with the request, the warning code will be present in the `#err` attribute
on the response object. No errors will be raised and a `MinfraudClient::Response` will be returned.

The possible warning codes are:
- `IP_NOT_FOUND`
  - This is an error from minFraud's perspective - it is returned if the IP address is not valid,
    if it is not public, or if it is not in minFraud's GeoIP database.
  - The client treats this as a warning instead of an error to allow a `risk_score` to be retrieved.
- `COUNTRY_NOT_FOUND`
- `CITY_NOT_FOUND`
- `CITY_REQUIRED`
- `INVALID_EMAIL_MD5`
- `POSTAL_CODE_REQUIRED`
- `POSTAL_CODE_NOT_FOUND`

### Transaction fields

#### Required

| name          | type   | example                             | description |
| ------------- | ------ | ----------------------------------- | ----------- |
| ip            | string | `t.ip = '1.2.3.4'`                  | Customer IP address  |
| txn_id        | string | `t.txn_id = 'Order-1'`              | Transaction/order id |
| license_key   | string | `t.license_key = 'default_license'` | MaxMind license key  |

#### Optional

| name               | type    | description |
| ------------------ | ------- | ----------- |
| city               | string  | Billing address city |
| state              | string  | Billing address region/state |
| postal             | string  | Billing address postal (zip) code |
| country            | string  | Billing address country as full country name or as an [ISO 3166](https://en.wikipedia.org/wiki/ISO_3166) code |
| ship_addr          | string  | Shipping street address |
| ship_city          | string  | Shipping address city |
| ship_state         | string  | Shipping address region/state |
| ship_postal        | string  | Shipping address postal (zip) code |
| ship_country       | string  | Shipping address country |
| email              | string  | Customer email - will be hashed using MD5 before sending |
| phone              | string  | Any format acceptable |
| bin                | string  | CC bin number (first 6 digits) |
| user_agent         | string  | Used for linking transactions |
| accept_language    | string  | Used for linking transactions |
| amount             | numeric | Transaction amount - A string representation of a numeric is also accepted |
| currency           | string  | [ISO 4217](https://en.wikipedia.org/wiki/ISO_4217) currency code |
| txn_type           | string  | `creditcard`/`debitcard`/`paypal`/`google`/`other`/`lead`/`survey`/`sitereg` |
| shop_id            | string  | Shop ID - If the input is not a string, the client will convert it using `.to_s` |
| avs_result         | string  | Standard AVS response code |
| cvv_result         | string  | CVV code represented as a single letter |
| requested_type     | string  | `standard`/`premium` |

### Connection Details

The HTTP client used by `Minfraud::MinfraudClient` is [Faraday](https://github.com/lostisland/faraday), which allows for
different middleware and adapters to customize how requests are sent.

We are using the [net-http-persistent](https://github.com/drbrain/net-http-persistent) adapter that keeps connections
alive between requests. Connections are shared in a connection pool, making the client more robust to network failures
and also speeds up request times.

`Minfraud::MinfraudClient` can be customized with the following parameters upon initialization:

| parameter     | type    | default value                  | description |
| ------------- | ------- | ------------------------------ | ----------- |
| host_choice   | string  | `https://minfraud.maxmind.com` | Base URL to send requests to. `us_east`/`us_west`/`eu_west` can be used to select pre-defined hosts. A custom URL can also be passed in. |
| open_timeout  | integer | `1`                            | Seconds to wait for a connection to be opened |
| idle_timeout  | integer | `5`                            | Seconds before automatically be resetting an unused connection |
| read_timeout  | integer | `5`                            | Seconds to wait until reading one block |
| write_timeout | integer | `5`                            | Seconds to wait until writing one block |
| pool_size     | integer | `10`                           | Maximum number of connections allowed at once |

### Immutability

`Minfraud::Transaction` and `Minfraud::Response` are both made immutable (frozen) after initialization.

This allows transactions and responses to be used as value objects with a guarantee that their attributes do not change.
