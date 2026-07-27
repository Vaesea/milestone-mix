package states;

import objects.BonusBlockArea;
import flixel.FlxObject;
import characters.enemies.Enemy;
import characters.enemies.Nolok;
import characters.player.Fireball;
import characters.player.Tux;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.addons.editors.tiled.TiledTileLayer;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
import objects.BonusBlock;
import objects.BrickBlock.CoinNormalBrickBlock;
import objects.BrickBlock.EmptyNormalBrickBlock;
import objects.Coin;
import objects.powerup.Egg;
import objects.powerup.FireFlower;
import objects.powerup.PowerUp;
import objects.powerup.TuxDoll;
import objects.solid.Goal;
import states.substates.LevelIntro;

class PlayState extends FlxState
{
	public var map:FlxTilemap;
	public var uhoh = 49; // because i added a fucking nolok tile in the creatures tileset, the global id shifted to 49.

	// Add things part 1
	public var enemies(default, null):FlxTypedGroup<Enemy>;
	public var bosses(default, null):FlxTypedGroup<Nolok>; // i wonder if this allows for multiple noloks? that'd be fun.
	public var tux(default, null):Tux;
	public var items(default, null):FlxTypedGroup<FlxSprite>;
	public var td(default, null):FlxTypedGroup<TuxDoll>;
	public var blocks(default, null):FlxTypedGroup<FlxObject>;
	public var bricks(default, null):FlxTypedGroup<FlxSprite>; // Unused
	public var atiles(default, null):FlxTypedGroup<FlxSprite>;
	public var atilesFront(default, null):FlxTypedGroup<FlxSprite>;
	var hud:HUD;
	var entities:FlxGroup;
	public var solidThings:FlxGroup;

	public var checkpoint:FlxPoint;

	override public function create()
	{
		// Just so Global.PS actually works...
		Global.PS = this;

		// Add things part 2
		entities = new FlxGroup();
		solidThings = new FlxGroup();
		enemies = new FlxTypedGroup<Enemy>();
		bosses = new FlxTypedGroup<Nolok>();
		tux = new Tux();
		td = new FlxTypedGroup<TuxDoll>();
		items = new FlxTypedGroup<FlxSprite>();
		blocks = new FlxTypedGroup<FlxObject>();
		bricks = new FlxTypedGroup<FlxSprite>();
		hud = new HUD();
		atiles = new FlxTypedGroup<FlxSprite>();
		atilesFront = new FlxTypedGroup<FlxSprite>();

		// Set Tux's current state
		tux.currentState = Global.tuxState;
		tux.reloadGraphics();

		LevelLoader.loadLevel(this, Global.currentLevel);

		// Add things part 3
		entities.add(items);
		entities.add(enemies);
		entities.add(bosses);
		add(solidThings);
		add(atiles);
		add(map);
		add(td);
		add(blocks);
		add(entities);
		add(tux);
		add(atilesFront);
		add(hud);

		// Camera
		FlxG.camera.follow(tux, PLATFORMER);
		FlxG.camera.setScrollBoundsRect(0, 0, map.width, map.height, true);

		// Foreground Layer, just realized I added this in the worst way possible. Oh well, too bad!
		var foregroundLayer:TiledTileLayer = cast LevelLoader.tiledMap.getLayer("Foreground");
        
        var foregroundMap = new FlxTilemap();
        foregroundMap.loadMapFromArray(foregroundLayer.tileArray, LevelLoader.tiledMap.width, LevelLoader.tiledMap.height, "assets/images/tiles.png", 32, 32, uhoh);
        foregroundMap.solid = false;

		add(foregroundMap);

		// Start the Level Intro
		openSubState(new LevelIntro(FlxColor.BLACK));

		trace(Global.checkpointReached);
		
		super.create();
	}

	override public function update(elapsed:Float)
	{
		updateCheckpoint();

		// Tux collision
		FlxG.overlap(entities, tux, collideEntities);
		FlxG.collide(solidThings, tux, collideEntities);
		FlxG.overlap(td, tux, collideEntities);
		FlxG.overlap(tux, blocks, function(tux:Tux, area:BonusBlockArea) // anatolystev's fix!
		{
			area.block.hit(tux);
		});

		// Enemy + Entity collision
		FlxG.collide(solidThings, entities);
		FlxG.overlap(entities, enemies, function (entity:FlxSprite, enemy:Enemy)
		{
			if (Std.isOfType(entity, Enemy))
			{
				enemy.collideOtherEnemy(cast entity);
			}
			if (Std.isOfType(entity, Fireball))
			{
				enemy.collideFireball(cast entity);
			}
		} );

		// Item collision
		FlxG.collide(solidThings, items);

		super.update(elapsed);
	}

	function collideEntities(entity:FlxSprite, tux:Tux)
	{
		if (Std.isOfType(entity, Enemy))
		{
			(cast entity).interact(tux);
		}
		
		if (Std.isOfType(entity, Nolok))
		{
			(cast entity).interact(tux);
		}

		if (Std.isOfType(entity, Coin))
		{
			(cast entity).collect();
		}

		if (Std.isOfType(entity, PowerUp) || Std.isOfType(entity, FireFlower) || Std.isOfType(entity, Egg) || Std.isOfType(entity, TuxDoll))
		{
			(cast entity).collect(tux);
		}

		if (Std.isOfType(entity, EmptyNormalBrickBlock) || Std.isOfType(entity, CoinNormalBrickBlock) || Std.isOfType(entity, BonusBlock))
		{
			(cast entity).hit(tux);
		}

		if (Std.isOfType(entity, Goal))
		{
			(cast entity).reach(tux);
		}
	}

	function updateCheckpoint()
	{
		if (checkpoint == null || Global.checkpointReached)
		{
			return;
		}

		if (tux.x >= checkpoint.x)
		{
			trace("Checkpoint reached!");
			Global.checkpointReached = true;
			trace(Global.checkpointReached);
		}
	}
}
