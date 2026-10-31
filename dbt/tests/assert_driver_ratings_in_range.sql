select
    driver_id,
    rating
from {{ ref('stg_drivers') }}
where rating < 0
   or rating > 5
