select
    driver_id,
    joined_date
from {{ ref('stg_drivers') }}
where joined_date > current_date
