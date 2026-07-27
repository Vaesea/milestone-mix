package objects;

import flixel.FlxObject;
import characters.player.Tux;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.tweens.FlxTween;
import objects.powerup.PowerUp;
import objects.powerup.TuxDoll;

class BonusBlock extends FlxSprite
{
    public var content:String;
    public var isEmpty = false;
    public var hitArea:FlxObject;

    var blockImage = FlxAtlasFrames.fromSparrow('assets/images/objects/bonus/bonusblock.png', 'assets/images/objects/bonus/bonusblock.xml');

    public function new(x:Float, y:Float)
    {
        super(x, y);
        solid = true;
        immovable = true;

        frames = blockImage;
        animation.addByPrefix('full', 'bonusblock full', 12, true); // I messed up and used default settings for the FNF Spritesheet and XML generator.
        animation.addByPrefix('empty', 'bonusblock empty', 12, false);
        animation.play("full");

        hitArea = new BonusBlockArea(this);
        Global.PS.blocks.add(hitArea);
    }

    public function hit(tux:Tux)
    {
        if (isEmpty)
        {
            return;
        }

        if (tux.isTouching(UP) || tux.wasTouching == UP) 
        {
            isEmpty = true;
            createItem();
            FlxTween.tween(this, {y: y - 4}, 0.05) .wait(0.05) .then(FlxTween.tween(this, {y: y}, 0.05, {onComplete: empty}));
        }
    }

    function empty(_)
    {
        animation.play("empty");
    }

    function createItem()
    {
        FlxG.sound.play("assets/sounds/brick.wav");
        switch(content)
        {
            default:
                var coin:Coin = new Coin(this.x, Std.int(y - 32));
                coin.setFromBlock();
                Global.PS.items.add(coin);
            
            case "fireflower":
                var fireFlower:PowerUp = new PowerUp(this.x, Std.int(y - 32));
                Global.PS.items.add(fireFlower);
                FlxG.sound.play("assets/sounds/upgrade.wav");

            case "tuxdoll":
                var tuxDoll:TuxDoll = new TuxDoll(this.x, Std.int(y - 32));
                Global.PS.td.add(tuxDoll);
                FlxG.sound.play("assets/sounds/upgrade.wav");
        }
    }
}