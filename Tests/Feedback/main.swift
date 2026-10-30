import Foundation

for (count,expected) in [(0,"0"),(99999,"99999"),(100000,"10万"),(109999,"10.9万"),(999999,"99.9万"),(100000000,"1亿"),(123456789,"1.2亿")] {
    assert(compactActionCount(count)==expected)
}
var data=AppData()
data.keys=["2030-01-01":18000];data.mouseClicks=["2030-01-01":7654]
let before=data.totalActions,keys=data.keys,mouse=data.mouseClicks,coins=data.garden.coins
assert(data.availableActions==25654 && data.typingReward==2)
assert(data.redeemTyping())
assert(data.availableActions==5654 && data.garden.coins==coins+2)
assert(data.totalActions==before && data.keys==keys && data.mouseClicks==mouse)
assert(!data.redeemTyping() && data.availableActions==5654)
var life=ToastLifetime()
life.advance(1);life.hovered=true;life.advance(100)
assert(life.elapsed==1 && life.opacity==1 && !life.expired)
life.hovered=false;life.advance(2)
assert(life.opacity>0 && life.opacity<1 && !life.expired)
life.advance(0.5);assert(life.expired && life.opacity==0)
print("PASS: compact action amounts, independent redeemed balance, preserved totals and hover-paused toast lifetime")
