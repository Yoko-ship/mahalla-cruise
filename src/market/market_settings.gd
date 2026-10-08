class_name MarketSettings
extends Resource
## The avtobozor: daily used-car offers and the workshop that repairs them.

@export_range(1, 6) var offers: int = 3
## A used car costs this share of its new price, times its condition.
@export_range(0.1, 1.0) var used_price_share: float = 0.7
@export_range(10, 95) var condition_min: int = 50
@export_range(10, 95) var condition_max: int = 85
@export_range(1, 50) var condition_step: int = 5
## A car at 0% would steer and hold fuel at this share; 100% is like new.
@export_range(0.1, 1.0) var worn_factor: float = 0.7
## One repair adds this many percent and costs this share of the car's new price.
@export_range(1, 100) var repair_step: int = 10
@export_range(0.0, 1.0) var repair_price_share: float = 0.06
@export_range(0, 10000) var repair_price_min: int = 20
