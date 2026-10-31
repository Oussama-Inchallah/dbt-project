select
    ride_id,
    fare_amount
from {{ ref('fact_rides') }}
where fare_amount < 0