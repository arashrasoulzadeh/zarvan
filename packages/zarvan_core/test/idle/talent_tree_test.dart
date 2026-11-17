import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_core/zarvan_core_idle.dart';
import 'package:test/test.dart';

BigNumber n(String s) => BigNumber.parse(s);

/// A talent tree is research nodes priced in the prestige currency: the
/// existing economy already supports it, this pins that down.
void main() {
  test('talents cost prestige stars, chain by requires, and stay bought', () {
    final world = World(width: 10, height: 10);
    registerCoreComponents(world);
    registerIdleComponents(world);
    final wallet = BigTreasury(amounts: {'coins': n('1e9'), 'stars': n('3')});
    world.componentsOf<BigTreasury>().set(world.spawn(), wallet);
    world.componentsOf<IdleModifiers>().set(world.spawn(), IdleModifiers());
    world.componentsOf<IdleStats>().set(world.spawn(), IdleStats());
    final root = world.spawn();
    final leaf = world.spawn();
    world.componentsOf<ResearchNode>()
      ..set(root, ResearchNode(id: 'thrift', cost: {'stars': n('1')}))
      ..set(
        leaf,
        ResearchNode(id: 'thrift_2', cost: {'stars': n('3')}, requires: ['thrift']),
      );

    expect(buyResearch(world, wallet, leaf).failure, BuyFailure.locked);
    expect(buyResearch(world, wallet, root).ok, isTrue);
    expect(wallet.of('stars').toDouble(), 2);
    expect(buyResearch(world, wallet, leaf).failure, BuyFailure.unaffordable);
    expect(buyResearch(world, wallet, root).failure, BuyFailure.alreadyBought);
  });
}
