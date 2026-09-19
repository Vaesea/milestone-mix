package collision;

// Collision - Simple (not really) class that does some cool collision stuff.
// Copyright (C) 2026 AnatolyStev
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

import flixel.util.FlxDirectionFlags;
import flixel.group.FlxGroup;
import flixel.FlxObject;

typedef SweepHit = 
{
    var time:Float;
    var normalX:Int;
    var normalY:Int;
    var other:FlxObject;
}

class Collision
{
    public static inline var skin:Float = 0.01;

    public static inline var max_iterations:Int = 4;

    public static inline var time_epsilon:Float = 0.000001;
    public static inline var move_epsilon:Float = 0.000001;

    /**
     * Resolves one moving FlxObject against all solid objects in the group.
     *
     * "onCollision" is called after the body's flags have been resolved, so
     * it's possible to safely use isTouching().
    */
    public static function resolve(body:FlxObject, solids:FlxGroup, ?onCollision:FlxObject->FlxObject->Void)
    {
        if (body == null || solids == null)
        {
            return;
        }

        if (!body.exists || !body.alive || !body.active || !body.moves || !body.solid || body.immovable)
        {
            return;
        }

        final targetX = body.x;
        final targetY = body.y;

        body.x = body.last.x;
        body.y = body.last.y;

        depenetrate(body, solids);

        var moveX = targetX - body.x;
        var moveY = targetY - body.y;

        for (_ in 0...max_iterations)
        {
            if (Math.abs(moveX) < move_epsilon && Math.abs(moveY) < move_epsilon)
            {
                break;
            }

            final hit = findEarliestHit(body, solids, moveX, moveY);
            
            if (hit == null)
            {
                body.x += moveX;
                body.y += moveY;
                break;
            }

            final time = hit.time;
            
            body.x += moveX * time;
            body.y += moveY * time;

            if (hit.normalX < 0)
            {
                body.x -= skin;
                body.touching |= RIGHT;
            }
            else if (hit.normalX > 0)
            {
                body.x += skin;
                body.touching |= LEFT;
            }

            if (hit.normalY < 0)
            {
                body.y -= skin;
                body.touching |= DOWN;
            }
            else if (hit.normalY > 0)
            {
                body.y += skin;
                body.touching |= UP;
            }

            if (hit.normalX != 0 && body.velocity.x * hit.normalX < 0)
            {
                body.velocity.x = 0;
            }

            if (hit.normalY != 0 && body.velocity.y * hit.normalY < 0)
            {
                body.velocity.y = 0;
            }

            if (onCollision != null)
            {
                onCollision(body, hit.other);
            }

            final remaining = 1.0 - time;

            moveX *= remaining;
            moveY *= remaining;

            if (hit.normalX != 0)
            {
                moveX = 0;
            }

            if (hit.normalY != 0)
            {
                moveY = 0;
            }

            if (remaining <= move_epsilon)
            {
                break;
            }
        }

        depenetrate(body, solids);
    }

    /**
     * Resolves every member (has to be alive) in a typed group against everything.
     * The group's members need to be FlxObject or a class that uses FlxObject.
    */
    public static function resolveGroup<T:FlxObject>(group:FlxTypedGroup<T>, solids:FlxGroup)
    {
        if (group == null || solids == null)
        {
            return;
        }

        for (member in group.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            resolve(member, solids);
        }
    }

    static function findEarliestHit(body:FlxObject, solids:FlxGroup, moveX:Float, moveY:Float):Null<SweepHit>
    {
        var bestTime = 1.0;
        var bestOther:FlxObject = null;
        var bestNormalX = 0;
        var bestNormalY = 0;

        final startX = body.x;
        final startY = body.y;
        final bodyWidth = body.width;
        final bodyHeight = body.height;

        final endX = startX + moveX;
        final endY = startY + moveY;

        final sweepLeft = moveX < 0 ? endX : startX;
        final sweepRight = moveX > 0 ? endX + bodyWidth : startX + bodyWidth;
        final sweepTop = moveY < 0 ? endY : startY;
        final sweepBottom = moveY > 0 ? endY + bodyHeight : startY + bodyHeight;

        for (member in solids.members)
        {
            if (member == null || !member.exists || !member.alive)
            {
                continue;
            }

            final solid:FlxObject = cast member;

            if (!solid.active || !solid.solid || solid == body || solid.width <= 0 || solid.height <= 0)
            {
                continue;
            }

            final solidRight = solid.x + solid.width;
            final solidBottom = solid.y + solid.height;

            if (sweepRight < solid.x || sweepLeft > solidRight || sweepBottom < solid.y || sweepTop > solidBottom)
            {
                continue;
            }

            final hit = sweepFast(body, solid, startX, startY, bodyWidth, bodyHeight, moveX, moveY, bestTime);

            if (hit == null)
            {
                continue;
            }

            if (hit.time < bestTime)
            {
                bestTime = hit.time;
                bestOther = hit.other;
                bestNormalX = hit.normalX;
                bestNormalY = hit.normalY;
            }
        }

        if (bestOther == null)
        {
            return null;
        }

        return {time: bestTime, normalX: bestNormalX, normalY: bestNormalY, other: bestOther};
    }

    static function sweepFast(body:FlxObject, solid:FlxObject, startX:Float, startY:Float, bodyWidth:Float, bodyHeight:Float, moveX:Float, moveY:Float, bestTime:Float):Null<SweepHit>
    {
        final bodyRight = startX + bodyWidth;
        final bodyBottom = startY + bodyHeight;
        final solidRight = solid.x + solid.width;
        final solidBottom = solid.y + solid.height;

        var xEntry:Float;
        var xExit:Float;

        if (moveX > 0)
        {
            xEntry = (solid.x - bodyRight) / moveX;
            xExit = (solidRight - startX) / moveX;
        }
        else if (moveX < 0)
        {
            xEntry = (solidRight - startX) / moveX;
            xExit = (solid.x - bodyRight) / moveX;
        }
        else
        {
            if (bodyRight <= solid.x || startX >= solidRight)
            {
                return null;
            }

            xEntry = Math.NEGATIVE_INFINITY;
            xExit = Math.POSITIVE_INFINITY;
        }

        if (xEntry > bestTime)
        {
            return null;
        }

        var yEntry:Float;
        var yExit:Float;

        if (moveY > 0)
        {
            yEntry = (solid.y - bodyBottom) / moveY;
            yExit = (solidBottom - startY) / moveY;
        }
        else if (moveY < 0)
        {
            yEntry = (solidBottom - startY) / moveY;
            yExit = (solid.y - bodyBottom) / moveY;
        }
        else
        {
            if (bodyBottom <= solid.y || startY >= solidBottom)
            {
                return null;
            }

            yEntry = Math.NEGATIVE_INFINITY;
            yExit = Math.POSITIVE_INFINITY;
        }

        final entryTime = xEntry > yEntry ? xEntry : yEntry;
        final exitTime = xExit < yExit ? xExit : yExit;

        if (entryTime > exitTime || entryTime < 0 || entryTime > 1 || entryTime > bestTime)
        {
            return null;
        }

        var normalX = 0;
        var normalY = 0;

        if (Math.abs(xEntry - entryTime) <= time_epsilon)
        {
            normalX = moveX > 0 ? -1 : 1;
        }

        if (Math.abs(yEntry - entryTime) <= time_epsilon)
        {
            normalY = moveY > 0 ? -1 : 1;
        }

        if (!canCollide(body, solid, normalX, normalY))
        {
            return null;
        }

        return {time: entryTime, normalX: normalX, normalY: normalY, other: solid};
    }

    static inline function canCollide(body:FlxObject, solid:FlxObject, normalX:Int, normalY:Int)
    {
        if (normalX < 0)
        {
            return body.allowCollisions.has(RIGHT) && solid.allowCollisions.has(LEFT);
        }
        if (normalX > 0)
        {
            return body.allowCollisions.has(LEFT) && solid.allowCollisions.has(RIGHT);
        }
        if (normalY < 0)
        {
            return body.allowCollisions.has(DOWN) && solid.allowCollisions.has(UP);
        }
        if (normalY > 0)
        {
            return body.allowCollisions.has(UP) && solid.allowCollisions.has(DOWN);
        }

        return false;
    }

    static function depenetrate(body:FlxObject, solids:FlxGroup)
    {
        for (_ in 0...max_iterations)
        {
            var changed = false;
            
            final bodyRight = body.x + body.width;
            final bodyBottom = body.y + body.height;
            final bodyCenterX = body.x + body.width * 0.5;
            final bodyCenterY = body.y + body.height * 0.5;

            for (member in solids.members)
            {
                if (member == null || !member.exists || !member.alive)
                {
                    continue;
                }

                final solid:FlxObject = cast member;

                if (!solid.active || !solid.solid || solid == body || solid.width <= 0 || solid.height <= 0)
                {
                    continue;
                }

                final solidRight = solid.x + solid.width;
                final solidBottom = solid.y + solid.height;

                final overlapX = bodyRight < solidRight ? bodyRight : solidRight;
                final leftX = body.x > solid.x ? body.x : solid.x;

                final penetrationX = overlapX - leftX;

                if (penetrationX <= 0)
                {
                    continue;
                }

                final overlapY = bodyBottom < solidBottom ? bodyBottom : solidBottom;
                final topY = body.y > solid.y ? body.y : solid.y;

                final penetrationY = overlapY - topY;

                if (penetrationY <= 0)
                {
                    continue;
                }

                final solidCenterX = solid.x + solid.width * 0.5;
                final solidCenterY = solid.y + solid.height * 0.5;

                if (penetrationX < penetrationY)
                {
                    if (bodyCenterX < solidCenterX)
                    {
                        if (!canCollide(body, solid, -1, 0))
                        {
                            continue;
                        }

                        body.x -= penetrationX + skin;
                        body.touching |= RIGHT;

                        if (body.velocity.x > 0)
                        {
                            body.velocity.x = 0;
                        }
                    }
                    else
                    {
                        if (!canCollide(body, solid, 1, 0))
                        {
                            continue;
                        }

                        body.x += penetrationX + skin;
                        body.touching |= LEFT;

                        if (body.velocity.x < 0)
                        {
                            body.velocity.x = 0;
                        }
                    }
                }
                else
                {
                    if (bodyCenterY < solidCenterY)
                    {
                        if (!canCollide(body, solid, 0, -1))
                        {
                            continue;
                        }

                        body.y -= penetrationY + skin;
                        body.touching |= DOWN;

                        if (body.velocity.y > 0)
                        {
                            body.velocity.y = 0;
                        }
                    }
                    else
                    {
                        if (!canCollide(body, solid, 0, 1))
                        {
                            continue;
                        }

                        body.y += penetrationY + skin;
                        body.touching |= UP;

                        if (body.velocity.y < 0)
                        {
                            body.velocity.y = 0;
                        }
                    }
                }

                changed = true;

                break;
            }

            if (!changed)
            {
                break;
            }
        }
    }
}