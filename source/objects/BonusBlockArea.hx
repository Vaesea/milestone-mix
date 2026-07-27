package objects;

// AnatolyStev

import flixel.FlxObject;

class BonusBlockArea extends FlxObject
{
    public var block:BonusBlock;

    public function new(block:BonusBlock)
    {
        super(block.x, block.y + 32, 32, 2);
        this.block = block;
    }
}