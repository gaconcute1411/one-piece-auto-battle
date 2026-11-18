class_name GachaSystem
extends RefCounted
## Logic triệu hồi (gacha). Không đụng tới UI.
## Quy tắc:
##  - Tỉ lệ bậc lấy từ GameData.TIER_RATES.
##  - Pity: đủ GameData.PITY_UR lượt chưa ra UR thì lượt đó chắc chắn UR.
##  - x10: nếu 9 lượt đầu chưa có bậc SP trở lên, lượt thứ 10 được đảm bảo.
##  - Trùng nhân vật: nhận 1 bản sao để nâng tối đa 15 sao.


static func cost_for(count: int) -> int:
	return GameData.PULL_COST_10 if count >= 10 else GameData.PULL_COST_1 * count


## Số lượt còn lại cho tới khi chắc chắn có UR.
static func pulls_until_pity() -> int:
	return maxi(1, GameData.PITY_UR - GameState.pity_ur)


## Thực hiện `count` lượt triệu hồi. Trả về mảng kết quả, hoặc [] nếu không đủ coin.
## Mỗi phần tử: {id, tier, is_new, star_up, stars, refund}
static func pull(count: int) -> Array:
	if count < 1:
		return []
	if not GameState.spend_coins(cost_for(count)):
		return []

	var results: Array = []
	var got_sp_or_better := false
	for i in range(count):
		var is_last_of_ten: bool = (count >= 10 and i == count - 1)
		var force_min: bool = is_last_of_ten and not got_sp_or_better
		var r := _roll_one(force_min)
		if GameData.TIER_RANK[r["tier"]] >= GameData.TIER_RANK[GameData.TEN_PULL_MIN_TIER]:
			got_sp_or_better = true
		results.append(r)

	GameState.total_pulls += count
	GameState.save_game()
	return results


static func _roll_one(force_min_tier: bool) -> Dictionary:
	GameState.pity_ur += 1
	var tier: String
	if GameState.pity_ur >= GameData.PITY_UR:
		tier = "UR"
	else:
		tier = _roll_tier(force_min_tier)
	if tier == "UR":
		GameState.pity_ur = 0

	var pool: Array = GameData.ids_by_tier(tier)
	var id: String = pool[randi() % pool.size()]
	var res: Dictionary = GameState.add_character(id)
	res["id"] = id
	res["tier"] = tier
	return res


static func _roll_tier(force_min_tier: bool) -> String:
	var min_rank: int = GameData.TIER_RANK[GameData.TEN_PULL_MIN_TIER] if force_min_tier else 0
	var total := 0.0
	for t in GameData.TIER_ORDER:
		if GameData.TIER_RANK[t] >= min_rank:
			total += float(GameData.TIER_RATES[t])
	var r := randf() * total
	var acc := 0.0
	for t in GameData.TIER_ORDER:          # UR -> SP -> SSR
		if GameData.TIER_RANK[t] < min_rank:
			continue
		acc += float(GameData.TIER_RATES[t])
		if r < acc:
			return t
	return GameData.TIER_ORDER[GameData.TIER_ORDER.size() - 1]
