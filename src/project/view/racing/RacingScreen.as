/*
 *      _________  __      __
 *    _/        / / /____ / /________ ____ ____  ___
 *   _/        / / __/ -_) __/ __/ _ `/ _ `/ _ \/ _ \
 *  _/________/  \__/\__/\__/_/  \_,_/\_, /\___/_//_/
 *                                   /___/
 * 
 * Tetragon : Game Engine for multi-platform ActionScript projects.
 * http://www.tetragonengine.com/
 * Copyright (c) The respective Copyright Holder (see LICENSE).
 * 
 * Permission is hereby granted, to any person obtaining a copy of this software
 * and associated documentation files (the "Software") under the rules defined in
 * the license found at http://www.tetragonengine.com/license/ or the LICENSE
 * file included within this distribution.
 * 
 * The above copyright notice and this permission notice must be included in all
 * copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND. THE COPYRIGHT
 * HOLDER AND ITS LICENSORS DISCLAIM ALL WARRANTIES AND CONDITIONS, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO ANY IMPLIED WARRANTIES AND CONDITIONS OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT, AND ANY
 * WARRANTIES AND CONDITIONS ARISING OUT OF COURSE OF DEALING OR USAGE OF TRADE.
 * NO ADVICE OR INFORMATION, WHETHER ORAL OR WRITTEN, OBTAINED FROM THE COPYRIGHT
 * HOLDER OR ELSEWHERE WILL CREATE ANY WARRANTY OR CONDITION NOT EXPRESSLY STATED
 * IN THIS AGREEMENT.
 */
package view.racing
{
	import tetragon.data.sprite.SpriteAtlas;
	import tetragon.input.KeyMode;
	import tetragon.util.display.centerChild;
	import tetragon.view.Screen;

	import view.racing.constants.COLORS;
	import view.racing.constants.ColorSet;
	import view.racing.constants.ROAD;
	import view.racing.parallax.ParallaxLayer;
	import view.racing.parallax.ParallaxScroller;
	import view.racing.vo.Car;
	import view.racing.vo.PCamera;
	import view.racing.vo.PPoint;
	import view.racing.vo.PScreen;
	import view.racing.vo.PWorld;
	import view.racing.vo.SSprite;
	import view.racing.vo.Segment;

	import com.hexagonstar.util.color.mixColors;

	import flash.display.Bitmap;
	import flash.display.BitmapData;
	
	
	/**
	 * @author Hexagon
	 */
	public class RacingScreen extends Screen
	{
		//-----------------------------------------------------------------------------------------
		// Constants
		//-----------------------------------------------------------------------------------------
		
		public static const ID:String = "racingScreen";
		
		
		//-----------------------------------------------------------------------------------------
		// Properties
		//-----------------------------------------------------------------------------------------
		
		private var _atlas:SpriteAtlas;
		private var _atlasImage:BitmapData;
		private var _renderBuffer:RenderBuffer;
		private var _bufferBitmap:Bitmap;
		private var _sprites:Sprites;
		
		private var _bgScroller:ParallaxScroller;
		private var _bgLayer1:ParallaxLayer;
		private var _bgLayer2:ParallaxLayer;
		private var _bgLayer3:ParallaxLayer;
		
		private var _segments:Vector.<Segment>;	// array of road segments
		private var _cars:Vector.<Car>;			// array of cars on the road
		
		private var _bufferWidth:int = 1024;
		private var _bufferHeight:int = 640;
		
		private var _dt:Number;					// how long is each frame (in seconds)
		private var _resolution:Number;			// scaling factor to provide resolution independence (computed)
		private var _drawDistance:int = 300;	// number of segments to draw
		private var _hazeDensity:int = 10;		// exponential fog density
		private var _cameraHeight:Number = 1000;// z height of camera
		private var _cameraDepth:Number;		// z distance camera is from screen (computed)
		private var _fieldOfView:int = 100;		// angle (degrees) for field of view
		
		private var _skySpeed:Number = 0.001;	// background sky layer scroll speed when going around curve (or up hill)
		private var _hillSpeed:Number = 0.002;	// background hill layer scroll speed when going around curve (or up hill)
		private var _treeSpeed:Number = 0.003;	// background tree layer scroll speed when going around curve (or up hill)
		
		private var _skyOffset:Number = 0;		// current sky scroll offset
		private var _hillOffset:Number = 0;		// current hill scroll offset
		private var _treeOffset:Number = 0;		// current tree scroll offset
		
		private var _playerX:Number = 0;		// player x offset from center of road (-1 to 1 to stay independent of roadWidth)
		private var _playerZ:Number;			// player relative z distance from camera (computed)
		
		private var _roadWidth:int = 2000;		// actually half the roads width, easier math if the road spans from -roadWidth to +roadWidth
		private var _segmentLength:int = 200;	// length of a single segment
		private var _rumbleLength:int = 3;		// number of segments per red/white rumble strip
		private var _trackLength:int = 200;		// z length of entire track (computed)
		private var _lanes:int = 3;				// number of lanes
		private var _totalCars:Number = 200;	// total number of cars on the road
		
		private var _accel:Number;				// acceleration rate - tuned until it 'felt' right
		private var _breaking:Number;			// deceleration rate when braking
		private var _decel:Number;				// 'natural' deceleration rate when neither accelerating, nor braking
		private var _offRoadDecel:Number = 0.99;// speed multiplier when off road (e.g. you lose 2% speed each update frame)
		private var _offRoadLimit:Number;		// limit when off road deceleration no longer applies (e.g. you can always go at least this speed even when off road)
		private var _centrifugal:Number = 0.3;	// centrifugal force multiplier when going around curves
		
		private var _position:Number;			// current camera Z position (add playerZ to get player's absolute Z position)
		private var _speed:Number;				// current speed
		private var _maxSpeed:Number;			// top speed (ensure we can't move more than 1 segment in a single frame to make collision detection easier)
		
		private var _currentLapTime:Number = 0; // current lap time
		private var _lastLapTime:Number = 0;	// last lap time
		private var _fast_lap_time:Number;
		
		private var _isAccelerate:Boolean;
		private var _isBrake:Boolean;
		private var _isSteerLeft:Boolean;
		private var _isSteerRight:Boolean;
		
		
		//-----------------------------------------------------------------------------------------
		// Signals
		//-----------------------------------------------------------------------------------------
		
		
		//-----------------------------------------------------------------------------------------
		// Public Methods
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		override public function start():void
		{
			super.start();
			reset();
			main.statsMonitor.toggle();
			main.gameLoop.start();
		}
		
		
		/**
		 * @inheritDoc
		 */
		override public function update():void
		{
			super.update();
		}
		
		
		/**
		 * @inheritDoc
		 */
		override public function reset():void
		{
			super.reset();
			
			_dt = 1 / main.gameLoop.frameRate;
			_maxSpeed = _segmentLength / _dt;
			_accel = _maxSpeed / 5;
			_breaking = -_maxSpeed;
			_decel = -_maxSpeed / 5;
			_offRoadLimit = _maxSpeed / 4;
			_cameraDepth = 1 / Math.tan((_fieldOfView / 2) * Math.PI / 180);
			_playerZ = (_cameraHeight * _cameraDepth);
			_resolution = 1.6; //_bufferHeight / _bufferHeight;
			_position = 0;
			_speed = 0;
			_cars = new Vector.<Car>();
			
			resetRoad();
			//resetSprites();
			//resetCars();
		}
		
		
		/**
		 * @inheritDoc
		 */
		override public function stop():void
		{
			super.stop();
			main.gameLoop.stop();
		}
		
		
		/**
		 * @inheritDoc
		 */
		override public function dispose():void
		{
			super.dispose();
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Accessors
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		override protected function get unload():Boolean
		{
			return true;
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Callback Handlers
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		override protected function onStageResize():void
		{
			super.onStageResize();
		}
		
		
		/**
		 * @private
		 */
		private function onKeyDown(key:String):void
		{
			switch (key)
			{
				case "u": _isAccelerate = true; break;
				case "d": _isBrake = true; break;
				case "l": _isSteerLeft = true; break;
				case "r": _isSteerRight = true; break;
			}
		}
		
		
		/**
		 * @private
		 */
		private function onKeyUp(key:String):void
		{
			switch (key)
			{
				case "u": _isAccelerate = false; break;
				case "d": _isBrake = false; break;
				case "l": _isSteerLeft = false; break;
				case "r": _isSteerRight = false; break;
			}
		}
		
		
		/**
		 * @private
		 */
		private function onTick():void
		{
			var n:int, car:Car, carW:Number, sprite:SSprite, spriteW:Number;
			var playerSegment:Segment = findSegment(_position + _playerZ);
			var playerW:Number = _sprites.PLAYER_STRAIGHT.width * _sprites.SCALE;
			var speedPercent:Number = _speed / _maxSpeed;
			var dx:Number = _dt * 2 * speedPercent;
			
			// at top speed, should be able to cross from left to right (-1
			// to 1) in 1 second
			var startPosition:Number = _position;

			updateCars(_dt, playerSegment, playerW);

			_position = increase(_position, _dt * _speed, _trackLength);

			if (_isSteerLeft)
				_playerX = _playerX - dx;
			else if (_isSteerRight)
				_playerX = _playerX + dx;

			_playerX = _playerX - (dx * speedPercent * playerSegment.curve * _centrifugal);

			if (_isAccelerate)
				_speed = accelerate(_speed, _accel, _dt);
			else if (_isBrake)
				_speed = accelerate(_speed, _breaking, _dt);
			else
				_speed = accelerate(_speed, _decel, _dt);

			if ((_playerX < -1) || (_playerX > 1))
			{
				if (_speed > _offRoadLimit)
					_speed = accelerate(_speed, _offRoadDecel, _dt);

				for (n = 0; n < playerSegment.sprites.length; n++)
				{
					sprite = playerSegment.sprites[n];
					spriteW = sprite.source.width * _sprites.SCALE;
					if (overlap(_playerX, playerW, sprite.offset + spriteW / 2 * (sprite.offset > 0 ? 1 : -1), spriteW))
					{
						_speed = _maxSpeed / 5;
						_position = increase(playerSegment.p1.world.z, -_playerZ, _trackLength);
						// stop
						// in
						// front
						// of
						// sprite
						// (at
						// front
						// of
						// segment)
						break;
					}
				}
			}

			for (n = 0; n < playerSegment.cars.length; n++)
			{
				car = playerSegment.cars[n];
				carW = car.sprite.source.width * _sprites.SCALE;
				if (_speed > car.speed)
				{
					if (overlap(_playerX, playerW, car.offset, carW, 0.8))
					{
						_speed = car.speed * (car.speed / _speed);
						_position = increase(car.z, -_playerZ, _trackLength);
						break;
					}
				}
			}

			_playerX = limit(_playerX, -3, 3);
			// dont ever let it go too far out of bounds
			_speed = limit(_speed, 0, _maxSpeed);
			// or exceed maxSpeed

			_skyOffset = increase(_skyOffset, _skySpeed * playerSegment.curve * (_position - startPosition) / _segmentLength, 1);
			_hillOffset = increase(_hillOffset, _hillSpeed * playerSegment.curve * (_position - startPosition) / _segmentLength, 1);
			_treeOffset = increase(_treeOffset, _treeSpeed * playerSegment.curve * (_position - startPosition) / _segmentLength, 1);

			if (_position > _playerZ)
			{
				if (_currentLapTime && (startPosition < _playerZ))
				{
					_lastLapTime = _currentLapTime;
					_currentLapTime = 0;
					if (_lastLapTime <= toFloat(_fast_lap_time))
					{
					}
					else
					{
					}
				}
				else
				{
					_currentLapTime += _dt;
				}
			}
		}
		
		
		/**
		 * @private
		 */
//		private function onTickOld():void
//		{
//			var n:int;
//			var car:Car;
//			var carW:Number;
//			var sprite:SSprite;
//			var spriteW:Number;
//			var playerSegment:Segment = findSegment(_position + _playerZ);
//			var playerW:Number = _sprites.PLAYER_STRAIGHT.width * _sprites.SCALE;
//			var speedPercent:Number = _speed / _maxSpeed;
//			var startPosition:Number = _position;
//			
//			// at top speed, should be able to cross from left to right (-1 to 1) in 1 second
//			var dx:Number = _dt * 2 * speedPercent;
//
//			updateCars(_dt, playerSegment, playerW);
//
//			_position = increase(_position, _dt * _speed, _trackLength);
//			
//			/* Check left/right steering. */
//			if (_isSteerLeft) _playerX = _playerX - dx;
//			else if (_isSteerRight) _playerX = _playerX + dx;
//			
//			/* Update player X position. */
//			_playerX = _playerX - (dx * speedPercent * playerSegment.curve * _centrifugal);
//			
//			/* Check acceleration and deceleration. */
//			if (_isAccelerate) _speed = accelerate(_speed, _accel, _dt);
//			else if (_isBrake) _speed = accelerate(_speed, _breaking, _dt);
//			else _speed = accelerate(_speed, _decel, _dt);
//			
//			/* Check if player steers off-road. */
//			if ((_playerX < -1) || (_playerX > 1))
//			{
//				if (_speed > _offRoadLimit) _speed = accelerate(_speed, _offRoadDecel, _dt);
//				
//				for (n = 0; n < playerSegment.sprites.length; n++)
//				{
//					sprite = playerSegment.sprites[n];
//					spriteW = sprite.source.width * _sprites.SCALE;
//					
//					/* Check collision with road-side obstacles. */
//					if (overlap(_playerX, playerW, sprite.offset + spriteW / 2 * (sprite.offset > 0 ? 1 : -1), spriteW))
//					{
//						_speed = _maxSpeed / 5; // stop in front of sprite (at front of segment)
//						_position = increase(playerSegment.p1.world.z, -_playerZ, _trackLength);
//						break;
//					}
//				}
//			}
//			
//			/* Check collision with other cars. */
//			for (n = 0; n < playerSegment.cars.length; n++)
//			{
//				car = playerSegment.cars[n];
//				carW = car.sprite.source.width * _sprites.SCALE;
//				if (_speed > car.speed)
//				{
//					if (overlap(_playerX, playerW, car.offset, carW, 0.8))
//					{
//						_speed = car.speed * (car.speed / _speed);
//						_position = increase(car.z, -_playerZ, _trackLength);
//						break;
//					}
//				}
//			}
//			
//			/* Limit player steering bounds and max speed. */
//			_playerX = limit(_playerX, -3, 3);
//			_speed = limit(_speed, 0, _maxSpeed);
//			
//			/* Calculate background layers parallax offsets. */
//			_skyOffset = increase(_skyOffset, _skySpeed * playerSegment.curve * speedPercent, 1);
//			_hillOffset = increase(_hillOffset, _hillSpeed * playerSegment.curve * speedPercent, 1);
//			_treeOffset = increase(_treeOffset, _treeSpeed * playerSegment.curve * speedPercent, 1);
//		}
		
		
		/**
		 * @private
		 */
		private function onRender(ticks:uint, ms:uint, fps:uint):void
		{
			var baseSegment:Segment = findSegment(_position);
			var basePercent:Number = percentRemaining(_position, _segmentLength);
			var playerSegment:Segment = findSegment(_position + _playerZ);
			var playerPercent:Number = percentRemaining(_position + _playerZ, _segmentLength);
			var playerY:Number = interpolate(playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent);
			var maxy:Number = _bufferHeight;
			
			var x:Number = 0;
			var dx:Number = -(baseSegment.curve * basePercent);
			
			_renderBuffer.clear();
			
			renderBackground(_sprites.BG_SKY, _skyOffset, _resolution * _skySpeed * playerY);
			//renderBackground(_sprites.BG_HILLS, _hillOffset, _resolution * _hillSpeed * playerY);
			//renderBackground(_sprites.BG_TREES, _treeOffset, _resolution * _treeSpeed * playerY);
			
			var n:int, i:int, segment:Segment, car:Car, sprite:SSprite, spriteScale:Number, spriteX:Number, spriteY:Number;

			/* PHASE 1: render segments, front to back and clip far segments that have been
			 * obscured by already rendered near segments if their projected coordinates are
			 * lower than maxY. */
			for (n = 0; n < _drawDistance; n++)
			{
				segment = _segments[(baseSegment.index + n) % _segments.length];
				segment.looped = segment.index < baseSegment.index;
				segment.haze = exponentialHaze(n / _drawDistance, _hazeDensity);
				segment.clip = maxy;

				project(segment.p1, (_playerX * _roadWidth) - x, playerY + _cameraHeight, _position - (segment.looped ? _trackLength : 0), _cameraDepth, _bufferWidth, _bufferHeight, _roadWidth);
				project(segment.p2, (_playerX * _roadWidth) - x - dx, playerY + _cameraHeight, _position - (segment.looped ? _trackLength : 0), _cameraDepth, _bufferWidth, _bufferHeight, _roadWidth);

				x = x + dx;
				dx = dx + segment.curve;

				if ((segment.p1.camera.z <= _cameraDepth) || // behind us 
				(segment.p2.screen.y >= segment.p1.screen.y) || // back face cull 
				(segment.p2.screen.y >= maxy)) // clip by (already rendered) hill
					continue;

				renderSegment(segment.p1.screen.x, segment.p1.screen.y, segment.p1.screen.w, segment.p2.screen.x, segment.p2.screen.y, segment.p2.screen.w, segment.haze, segment.color);
				
				maxy = segment.p1.screen.y;
			}
			
			/* PHASE 2: Back to front render the sprites. */
			for (n = (_drawDistance - 1); n > 0; n--)
			{
				segment = _segments[(baseSegment.index + n) % _segments.length];

				for (i = 0; i < segment.cars.length; i++)
				{
					car = segment.cars[i];
					sprite = car.sprite;
					spriteScale = interpolate(segment.p1.screen.scale, segment.p2.screen.scale, car.percent);
					spriteX = interpolate(segment.p1.screen.x, segment.p2.screen.x, car.percent) + (spriteScale * car.offset * _roadWidth * _bufferWidth / 2);
					spriteY = interpolate(segment.p1.screen.y, segment.p2.screen.y, car.percent);
					renderSprite(_roadWidth, car.sprite.source, spriteScale, spriteX, spriteY, -0.5, -1, segment.clip);
				}
				
				for (i = 0; i < segment.sprites.length; i++)
				{
					sprite = segment.sprites[i];
					spriteScale = segment.p1.screen.scale;
					spriteX = segment.p1.screen.x + (spriteScale * sprite.offset * _roadWidth * _bufferWidth / 2);
					spriteY = segment.p1.screen.y;
					renderSprite(_roadWidth, sprite.source, spriteScale, spriteX, spriteY, (sprite.offset < 0 ? -1 : 0), -1, segment.clip);
				}
				
				if (segment == playerSegment)
				{
					renderPlayer(_roadWidth, _speed / _maxSpeed, _cameraDepth / _playerZ, _bufferWidth / 2, (_bufferHeight / 2) - (_cameraDepth / _playerZ * interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent) * _bufferHeight / 2), _speed * (_isSteerLeft ? -1 : _isSteerRight ? 1 : 0), playerSegment.p2.world.y - playerSegment.p1.world.y);
				}
			}
		}
		
		
		/**
		 * @private
		 */
//		private function onRenderOld(ticks:uint, ms:uint, fps:uint):void
//		{
//			var baseSegment:Segment = findSegment(_position);
//			var basePercent:Number = percentRemaining(_position, _segmentLength);
//			var playerSegment:Segment = findSegment(_position + _playerZ);
//			var playerPercent:Number = percentRemaining(_position + _playerZ, _segmentLength);
//			var playerY:Number = interpolate(playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent);
//			var maxY:Number = _bufferHeight;
//			var x:Number = 0;
//			var dx:Number = - (baseSegment.curve * basePercent);
//			
//			var n:int;
//			var i:int;
//			var s:Segment;
//			var car:Car;
//			var sprite:SSprite;
//			var spriteScale:Number;
//			var spriteX:Number;
//			var spriteY:Number;
//			
//			_renderBuffer.clear();
//			
//			/* Render background layers. */
//			renderBackground(_skyOffset, _resolution * _skySpeed  * playerY);
//			renderBackground(_hillOffset, _resolution * _hillSpeed  * playerY);
//			renderBackground(_treeOffset, _resolution * _treeSpeed  * playerY);
//			
//			/* PHASE 1: render segments, front to back and clip far segments that have been
//			 * obscured by already rendered near segments if their projected coordinates are
//			 * lower than maxy. */
//			for (n = 0; n < _drawDistance; n++)
//			{
//				s = _segments[(baseSegment.index + n) % _segments.length];
//				s.looped = s.index < baseSegment.index;
//				s.fog = exponentialFog(n / _drawDistance, _fogDensity);
//				s.clip = maxY;
//				
//				project(s.p1, (_playerX * _roadWidth) - x, playerY + _cameraHeight, _position - (s.looped ? _trackLength : 0), _cameraDepth, _bufferWidth, _bufferHeight, _roadWidth);
//				project(s.p2, (_playerX * _roadWidth) - x - dx, playerY + _cameraHeight, _position - (s.looped ? _trackLength : 0), _cameraDepth, _bufferWidth, _bufferHeight, _roadWidth);
//				
//				x = x + dx;
//				dx = dx + s.curve;
//				
//				if ((s.p1.camera.z <= _cameraDepth)				// behind us
//					|| (s.p2.screen.y >= s.p1.screen.y)			// back face cull
//					|| (s.p2.screen.y >= maxY))					// clip by (already rendered) hill
//				{
//					continue;
//				}
//				
//				renderSegment(s.p1.screen.x, s.p1.screen.y, s.p1.screen.w, s.p2.screen.x, s.p2.screen.y, s.p2.screen.w, s.fog, s.color);
//				maxY = s.p1.screen.y;
//			}
//			
//			/* PHASE 2: Back to front render the sprites. */
//			for (n = (_drawDistance - 1); n > 0; n--)
//			{
//				s = _segments[(baseSegment.index + n) % _segments.length];
//				
//				/* Render oponents. */
//				for (i = 0; i < s.cars.length; i++)
//				{
//					car = s.cars[i];
//					sprite = car.sprite;
//					spriteScale = interpolate(s.p1.screen.scale, s.p2.screen.scale, car.percent);
//					spriteX = interpolate(s.p1.screen.x, s.p2.screen.x, car.percent) + (spriteScale * car.offset * _roadWidth * _bufferWidth / 2);
//					spriteY = interpolate(s.p1.screen.y, s.p2.screen.y, car.percent);
//					renderSprite(_roadWidth, car.sprite.source, spriteScale, spriteX, spriteY, -0.5, -1, s.clip);
//				}
//				
//				/* Render decoration and obstacle sprites. */
//				for (i = 0; i < s.sprites.length; i++)
//				{
//					sprite = s.sprites[i];
//					spriteScale = s.p1.screen.scale;
//					spriteX = s.p1.screen.x + (spriteScale * sprite.offset * _roadWidth * _bufferWidth / 2);
//					spriteY = s.p1.screen.y;
//					renderSprite(_roadWidth, sprite.source, spriteScale, spriteX, spriteY, (sprite.offset < 0 ? -1 : 0), -1, s.clip);
//				}
//				
//				/* Render player sprite. */
//				if (s == playerSegment)
//				{
//					renderPlayer(
//						_roadWidth, _speed / _maxSpeed,
//						_cameraDepth / _playerZ,
//						_bufferWidth / 2,
//						(_bufferHeight / 2) - (_cameraDepth / _playerZ * interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent) * _bufferHeight / 2),
//						_speed * (_isSteerLeft ? -1 : _isSteerRight ? 1 : 0),
//						playerSegment.p2.world.y - playerSegment.p1.world.y);
//				}
//			}
//		}
		
		
		/**
		 * @private
		 */
//		private function onRenderOld(ticks:uint, ms:uint, fps:uint):void
//		{
//			var baseSegment:Segment = findSegment(_position);
//			var basePercent:Number = percentRemaining(_position, _segmentLength);
//			var playerSegment:Segment = findSegment(_position + _playerZ);
//			var playerPercent:Number = percentRemaining(_position + _playerZ, _segmentLength);
//			var playerY:Number = interpolate(playerSegment.p1.world.y, playerSegment.p2.world.y, playerPercent);
//			var maxY:Number = _bufferHeight;
//			var x:Number = 0;
//			var dx:Number = -(baseSegment.curve * basePercent);
//			var s:Segment;
//			var n:int;
//			
//			_renderBuffer.clear();
//			
//			/* Render background layers. */
//			renderBackground(_sprites.REGION_SKY, _skyOffset, _resolution * _skySpeed  * playerY);
//			renderBackground(_sprites.REGION_HILLS, _hillOffset, _resolution * _hillSpeed  * playerY);
//			renderBackground(_sprites.REGION_TREES, _treeOffset, _resolution * _treeSpeed  * playerY);
//			
//			/* Render road segments. */
//			for (n = 0; n < _drawDistance; n++)
//			{
//				s = _segments[(baseSegment.index + n) % _segments.length];
//				s.looped = s.index < baseSegment.index;
//				s.fog = exponentialFog(n / _drawDistance, _fogDensity);
//				
//				project(s.p1, (_playerX * _roadWidth) - x, playerY + _cameraHeight, _position - (s.looped ? _trackLength : 0), _cameraDepth, _bufferWidth, _bufferHeight, _roadWidth);
//				project(s.p2, (_playerX * _roadWidth) - x - dx, playerY + _cameraHeight, _position - (s.looped ? _trackLength : 0), _cameraDepth, _bufferWidth, _bufferHeight, _roadWidth);
//	
//				x = x + dx;
//				dx = dx + s.curve;
//				
//				if ((s.p1.camera.z <= _cameraDepth) || // behind us 
//					(s.p2.screen.y >= s.p1.screen.y) || // back face cull 
//					(s.p2.screen.y >= maxY))                  // clip by (already rendered) segment
//					continue;
//				
//				renderSegment(
//					s.p1.screen.x,
//					s.p1.screen.y,
//					s.p1.screen.w,
//					s.p2.screen.x,
//					s.p2.screen.y,
//					s.p2.screen.w,
//					s.fog,
//					s.color);
//				
//				maxY = s.p2.screen.y;
//			}
//			
//			/* Render the player sprite. */
//			renderPlayer(_roadWidth,
//				_speed / _maxSpeed,
//				_cameraDepth / _playerZ,
//				_bufferWidth / 2,
//				(_bufferHeight / 2) - (_cameraDepth / _playerZ * interpolate(playerSegment.p1.camera.y, playerSegment.p2.camera.y, playerPercent) * _bufferHeight / 2),
//				_speed * (_isSteerLeft ? -1 : _isSteerRight ? 1 : 0),
//				playerSegment.p2.world.y - playerSegment.p1.world.y);
//		}
		
		
		//-----------------------------------------------------------------------------------------
		// Private Methods
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @inheritDoc
		 */
		override protected function setup():void
		{
			super.setup();
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function registerResources():void
		{
			registerResource("spriteAtlas");
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function createChildren():void
		{
			main.keyInputManager.assign("CURSORUP", KeyMode.DOWN, onKeyDown, "u");
			main.keyInputManager.assign("CURSORDOWN", KeyMode.DOWN, onKeyDown, "d");
			main.keyInputManager.assign("CURSORLEFT", KeyMode.DOWN, onKeyDown, "l");
			main.keyInputManager.assign("CURSORRIGHT", KeyMode.DOWN, onKeyDown, "r");
			main.keyInputManager.assign("CURSORUP", KeyMode.UP, onKeyUp, "u");
			main.keyInputManager.assign("CURSORDOWN", KeyMode.UP, onKeyUp, "d");
			main.keyInputManager.assign("CURSORLEFT", KeyMode.UP, onKeyUp, "l");
			main.keyInputManager.assign("CURSORRIGHT", KeyMode.UP, onKeyUp, "r");
			
			resourceManager.process("spriteAtlas");
			_atlas = getResource("spriteAtlas");
			_atlasImage = _atlas.image;
			
			prepareSprites();
			
			_renderBuffer = new RenderBuffer(_bufferWidth, _bufferHeight, false, 0x000055);
			_bufferBitmap = new Bitmap(_renderBuffer);
			
			_bgLayer1 = new ParallaxLayer(_sprites.BG_SKY, _skySpeed);
			//_bgLayer2 = new ParallaxLayer(_sprites.BG_HILLS, _hillSpeed);
			//_bgLayer3 = new ParallaxLayer(_sprites.BG_TREES, _treeSpeed);
			
			_bgScroller = new ParallaxScroller(_bufferWidth, _sprites.BG_SKY.height);
			_bgScroller.layers = [_bgLayer1, _bgLayer2, _bgLayer3];
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function registerChildren():void
		{
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function addChildren():void
		{
			addChild(_bufferBitmap);
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function addListeners():void
		{
			main.gameLoop.tickSignal.add(onTick);
			main.gameLoop.renderSignal.add(onRender);
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function removeListeners():void
		{
			main.gameLoop.tickSignal.remove(onTick);
			main.gameLoop.renderSignal.remove(onRender);
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function executeBeforeStart():void
		{
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function updateDisplayText():void
		{
		}
		
		
		/**
		 * @inheritDoc
		 */
		override protected function layoutChildren():void
		{
			centerChild(_bufferBitmap);
		}
		
		
		/**
		 * @private
		 */
		private function prepareSprites():void
		{
			_sprites = new Sprites();
			_sprites.BG_SKY = _atlas.getSprite("bg_sky");
			_sprites.BG_HILLS = _atlas.getSprite("bg_hills");
			_sprites.BG_TREES = _atlas.getSprite("bg_trees");
			_sprites.BILLBOARD01 = _atlas.getSprite("sprite_billboard01");
			_sprites.BILLBOARD02 = _atlas.getSprite("sprite_billboard02");
			_sprites.BILLBOARD03 = _atlas.getSprite("sprite_billboard03");
			_sprites.BILLBOARD04 = _atlas.getSprite("sprite_billboard04");
			_sprites.BILLBOARD05 = _atlas.getSprite("sprite_billboard05");
			_sprites.BILLBOARD06 = _atlas.getSprite("sprite_billboard06");
			_sprites.BILLBOARD07 = _atlas.getSprite("sprite_billboard07");
			_sprites.BILLBOARD08 = _atlas.getSprite("sprite_billboard08");
			_sprites.BILLBOARD09 = _atlas.getSprite("sprite_billboard09");
			_sprites.BOULDER1 = _atlas.getSprite("sprite_boulder1");
			_sprites.BOULDER2 = _atlas.getSprite("sprite_boulder2");
			_sprites.BOULDER3 = _atlas.getSprite("sprite_boulder3");
			_sprites.BUSH1 = _atlas.getSprite("sprite_bush1");
			_sprites.BUSH2 = _atlas.getSprite("sprite_bush2");
			_sprites.CACTUS = _atlas.getSprite("sprite_cactus");
			_sprites.TREE1 = _atlas.getSprite("sprite_tree1");
			_sprites.TREE2 = _atlas.getSprite("sprite_tree2");
			_sprites.PALM_TREE = _atlas.getSprite("sprite_palm_tree");
			_sprites.DEAD_TREE1 = _atlas.getSprite("sprite_dead_tree1");
			_sprites.DEAD_TREE2 = _atlas.getSprite("sprite_dead_tree2");
			_sprites.STUMP = _atlas.getSprite("sprite_stump");
			_sprites.COLUMN = _atlas.getSprite("sprite_column");
			_sprites.CAR01 = _atlas.getSprite("sprite_car01");
			_sprites.CAR02 = _atlas.getSprite("sprite_car02");
			_sprites.CAR03 = _atlas.getSprite("sprite_car03");
			_sprites.CAR04 = _atlas.getSprite("sprite_car04");
			_sprites.SEMI = _atlas.getSprite("sprite_semi");
			_sprites.TRUCK = _atlas.getSprite("sprite_truck");
			_sprites.PLAYER_STRAIGHT = _atlas.getSprite("sprite_player_straight");
			_sprites.PLAYER_LEFT = _atlas.getSprite("sprite_player_left");
			_sprites.PLAYER_RIGHT = _atlas.getSprite("sprite_player_right");
			_sprites.PLAYER_UPHILL_STRAIGHT = _atlas.getSprite("sprite_player_uphill_straight");
			_sprites.PLAYER_UPHILL_LEFT = _atlas.getSprite("sprite_player_uphill_left");
			_sprites.PLAYER_UPHILL_RIGHT = _atlas.getSprite("sprite_player_uphill_right");
			
			_sprites.REGION_SKY = _atlas.getRegion("bg_sky");
			_sprites.REGION_HILLS = _atlas.getRegion("bg_hills");
			_sprites.REGION_TREES = _atlas.getRegion("bg_trees");
			
			_sprites.init();
		}
		
		
		//-----------------------------------------------------------------------------------------
		// ROAD GEOMETRY CONSTRUCTION
		//-----------------------------------------------------------------------------------------
		
		/**
		 * @private
		 */
		private function resetRoad():void
		{
			_segments = new Vector.<Segment>();
			
			addStraight(ROAD.LENGTH.SHORT / 2);
			addHill(ROAD.LENGTH.SHORT, ROAD.HILL.LOW);
			addLowRollingHills();
			addSCurves();
			addCurve(ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM, ROAD.HILL.LOW);
			addBumps();
			addLowRollingHills();
			addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM);
			addStraight();
			addCurve(ROAD.LENGTH.LONG, -ROAD.CURVE.MEDIUM, ROAD.HILL.MEDIUM);
			addHill(ROAD.LENGTH.LONG, ROAD.HILL.HIGH);
			addCurve(ROAD.LENGTH.LONG, ROAD.CURVE.MEDIUM, -ROAD.HILL.LOW);
			addHill(ROAD.LENGTH.LONG, -ROAD.HILL.MEDIUM);
			addStraight();
			addDownhillToEnd();
			
			_segments[findSegment(_playerZ).index + 2].color = COLORS.START;
			_segments[findSegment(_playerZ).index + 3].color = COLORS.START;
			
			for (var n:uint = 0 ; n < _rumbleLength ; n++)
			{
				_segments[_segments.length - 1 - n].color = COLORS.FINISH;
			}
			
			_trackLength = _segments.length * _segmentLength;
		}
		
		
		/**
		 * @private
		 */
		private function resetSprites():void
		{
			var n:int;
			var i:int;
			var side:Number;
			var sprite:BitmapData;
			var offset:Number;
			
			addSprite(20, _sprites.BILLBOARD07, -1);
			addSprite(40, _sprites.BILLBOARD06, -1);
			addSprite(60, _sprites.BILLBOARD08, -1);
			addSprite(80, _sprites.BILLBOARD09, -1);
			addSprite(100, _sprites.BILLBOARD01, -1);
			addSprite(120, _sprites.BILLBOARD02, -1);
			addSprite(140, _sprites.BILLBOARD03, -1);
			addSprite(160, _sprites.BILLBOARD04, -1);
			addSprite(180, _sprites.BILLBOARD05, -1);

			addSprite(240, _sprites.BILLBOARD07, -1.2);
			addSprite(240, _sprites.BILLBOARD06, 1.2);
			addSprite(_segments.length - 25, _sprites.BILLBOARD07, -1.2);
			addSprite(_segments.length - 25, _sprites.BILLBOARD06, 1.2);
			
			for (n = 10; n < 200; n += 4 + Math.floor(n / 100))
			{
				addSprite(n, _sprites.PALM_TREE, 0.5 + Math.random() * 0.5);
				addSprite(n, _sprites.PALM_TREE, 1 + Math.random() * 2);
			}
			
			for (n = 250; n < 1000; n += 5)
			{
				addSprite(n, _sprites.COLUMN, 1.1);
				addSprite(n + randomInt(0, 5), _sprites.TREE1, -1 - (Math.random() * 2));
				addSprite(n + randomInt(0, 5), _sprites.TREE2, -1 - (Math.random() * 2));
			}
			
			for (n = 200; n < _segments.length; n += 3)
			{
				addSprite(n, randomChoice(_sprites.PLANTS), randomChoice([1, -1]) * (2 + Math.random() * 5));
			}
			
			for (n = 1000; n < (_segments.length - 50); n += 100)
			{
				side = randomChoice([1, -1]);
				addSprite(n + randomInt(0, 50), randomChoice(_sprites.BILLBOARDS), -side);
				for (i = 0 ; i < 20 ; i++)
				{
					sprite = randomChoice(_sprites.PLANTS);
					offset = side * (1.5 + Math.random());
					addSprite(n + randomInt(0, 50), sprite, offset);
				}
			}
		}
		
		
		/**
		 * @private
		 */
		private function resetCars():void
		{
			var n:int,
			car:Car,
			segment:Segment,
			offset:Number,
			z:Number,
			sprite:BitmapData,
			speed:Number;
			
			for (n = 0; n < _totalCars; n++)
			{
				offset = Math.random() * randomChoice([-0.8, 0.8]);
				z = Math.floor(Math.random() * _segments.length) * _segmentLength;
				sprite = randomChoice(_sprites.CARS);
				speed = _maxSpeed / 4 + Math.random() * _maxSpeed / (sprite == _sprites.SEMI ? 4 : 2);
				car = new Car(offset, z, new SSprite(sprite), speed);
				segment = findSegment(car.z);
				segment.cars.push(car);
				_cars.push(car);
			}
		}
		
		
		/**
		 * @private
		 */
		private function addStraight(num:int = ROAD.LENGTH.MEDIUM):void
		{
			addRoad(num, num, num, 0, 0);
		}
		
		
		/**
		 * @private
		 */
		private function addCurve(num:int = ROAD.LENGTH.MEDIUM, curve:int = ROAD.CURVE.MEDIUM,
			height:int = ROAD.HILL.NONE):void
		{
			addRoad(num, num, num, curve, height);
		}
		
		
		/**
		 * @private
		 */
		private function addSCurves():void
		{
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.MEDIUM);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.CURVE.EASY);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.EASY);
			addRoad(ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, ROAD.LENGTH.MEDIUM, -ROAD.CURVE.MEDIUM);
		}
		
		
		/**
		 * @private
		 */
		private function addHill(num:int = ROAD.LENGTH.MEDIUM, height:int = ROAD.HILL.MEDIUM):void
		{
			addRoad(num, num, num, 0, height);
		}
		
		
		/**
		 * @private
		 */
		private function addLowRollingHills(num:int = ROAD.LENGTH.SHORT,
			height:int = ROAD.HILL.LOW):void
		{
			addRoad(num, num, num, 0, height / 2);
			addRoad(num, num, num, 0, -height);
			addRoad(num, num, num, ROAD.CURVE.EASY, height);
			addRoad(num, num, num, 0, 0);
			addRoad(num, num, num, -ROAD.CURVE.EASY, height / 2);
			addRoad(num, num, num, 0, 0);
		}
		
		
		/**
		 * @private
		 */
		private function addBumps():void
		{
			addRoad(10, 10, 10, 0, 5);
			addRoad(10, 10, 10, 0, -2);
			addRoad(10, 10, 10, 0, -5);
			addRoad(10, 10, 10, 0, 8);
			addRoad(10, 10, 10, 0, 5);
			addRoad(10, 10, 10, 0, -7);
			addRoad(10, 10, 10, 0, 5);
			addRoad(10, 10, 10, 0, -2);
		}


		/**
		 * @private
		 */
		private function addDownhillToEnd(num:int = 200):void
		{
			addRoad(num, num, num, -ROAD.CURVE.EASY, -lastY() / _segmentLength);
		}
		
		
		/**
		 * @private
		 */
		private function addRoad(enter:int, hold:int, leave:int, curve:Number, y:Number = NaN):void
		{
			var startY:Number = lastY();
			var endY:Number = startY + (toInt(y, 0) * _segmentLength);
			var i:uint;
			var total:uint = enter + hold + leave;
			
			for (i = 0; i < enter; i++)
			{
				addSegment(easeIn(0, curve, i / enter), easeInOut(startY, endY, i / total));
			}
			for (i = 0; i < hold; i++)
			{
				addSegment(curve, easeInOut(startY, endY, (enter + i) / total));
			}
			for (i = 0; i < leave; i++)
			{
				addSegment(easeInOut(curve, 0, i / leave), easeInOut(startY, endY, (enter + hold + i) / total));
			}
		}
		
		
		/**
		 * @private
		 */
		private function addSegment(curve:Number, y:Number):void
		{
			var i:uint = _segments.length;
			var segment:Segment = new Segment();
			segment.index = i;
			segment.p1 = new PPoint(new PWorld(lastY(), i * _segmentLength), new PCamera(), new PScreen());
			segment.p2 = new PPoint(new PWorld(y, (i + 1) * _segmentLength), new PCamera(), new PScreen());
			segment.curve = curve;
			segment.sprites = new Vector.<SSprite>();
			segment.cars = new Vector.<Car>();
			segment.color = Math.floor(i / _rumbleLength) % 2 ? COLORS.DARK : COLORS.LIGHT;
			_segments.push(segment);
		}
		
		
		/**
		 * @private
		 */
		private function addSprite(n:int, sprite:BitmapData, offset:Number):void
		{
			var s:SSprite = new SSprite(sprite, offset);
			_segments[n].sprites.push(s);
		}
		
		
		/**
		 * @private
		 */
		private function findSegment(z:Number):Segment
		{
			return _segments[Math.floor(z / _segmentLength) % _segments.length];
		}
		
		
		/**
		 * @private
		 */
		private function lastY():Number
		{
			return (_segments.length == 0) ? 0 : _segments[_segments.length - 1].p2.world.y;
		}
		
		
		/**
		 * @private
		 */
		private function updateCars(dt:Number, playerSegment:Segment, playerW:Number):void
		{
			var n:int;
			var car:Car;
			var oldSegment:Segment;
			var newSegment:Segment;
			
			for (n = 0; n < _cars.length; n++)
			{
				car = _cars[n];
				oldSegment = findSegment(car.z);
				car.offset = car.offset + updateCarOffset(car, oldSegment, playerSegment, playerW);
				car.z = increase(car.z, dt * car.speed, _trackLength);
				car.percent = percentRemaining(car.z, _segmentLength);
				// useful for interpolation during rendering phase
				newSegment = findSegment(car.z);
				
				if (oldSegment != newSegment)
				{
					var index:int = oldSegment.cars.indexOf(car);
					oldSegment.cars.splice(index, 1);
					newSegment.cars.push(car);
				}
			}
		}
		
		
		/**
		 * @private
		 */
		private function updateCarOffset(car:Car, carSegment:Segment, playerSegment:Segment, playerW:Number):Number
		{
			var i:int;
			var j:int;
			var dir:Number;
			var segment:Segment;
			var otherCar:Car;
			var otherCarW:Number;
			var lookahead:int = 20;
			var carW:Number = car.sprite.source.width * _sprites.SCALE;
			
			/* Optimization: dont bother steering around other cars when 'out of sight'
			 * of the player. */
			if ((carSegment.index - playerSegment.index) > _drawDistance) return 0;
			
			for (i = 1; i < lookahead; i++)
			{
				segment = _segments[(carSegment.index + i) % _segments.length];
				
				/* Car drive-around player AI */
				if ((segment === playerSegment)
					&& (car.speed > _speed)
					&& (overlap(_playerX, playerW, car.offset, carW, 1.2)))
				{
					if (_playerX > 0.5) dir = -1;
					else if (_playerX < -0.5) dir = 1;
					else dir = (car.offset > _playerX) ? 1 : -1;
					// The closer the cars (smaller i) and the greater the speed ratio,
					// the larger the offset.
					return dir * 1 / i * (car.speed - _speed) / _maxSpeed;
				}
				
				/* Car drive-around other car AI */
				for (j = 0; j < segment.cars.length; j++)
				{
					otherCar = segment.cars[j];
					otherCarW = otherCar.sprite.source.width * _sprites.SCALE;
					if ((car.speed > otherCar.speed)
						&& overlap(car.offset, carW, otherCar.offset, otherCarW, 1.2))
					{
						if (otherCar.offset > 0.5) dir = -1;
						else if (otherCar.offset < -0.5) dir = 1;
						else dir = (car.offset > otherCar.offset) ? 1 : -1;
						return dir * 1 / i * (car.speed - otherCar.speed) / _maxSpeed;
					}
				}
			}
			
			// if no cars ahead, but car has somehow ended up off road, then steer back on.
			if (car.offset < -0.9) return 0.1;
			else if (car.offset > 0.9) return -0.1;
			else return 0;
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Util Functions
		//-----------------------------------------------------------------------------------------
		
		private static function increase(start:Number, increment:Number, max:Number):Number
		{
			var result:Number = start + increment;
			while (result >= max) result -= max;
			while (result < 0) result += max;
			return result;
		}
		
		
		private static function accelerate(v:Number, accel:Number, dt:Number):Number
		{
			return v + (accel * dt);
		}
		
		
		private static function limit(value:Number, min:Number, max:Number):Number
		{
			return Math.max(min, Math.min(value, max));
		}
		
		
		private static function exponentialHaze(distance:Number, density:Number):Number
		{
			return 1 / (Math.pow(Math.E, (distance * distance * density)));
		}
		
		
		private static function project(p:PPoint, cameraX:Number, cameraY:Number, cameraZ:Number,
			cameraDepth:Number, width:Number, height:Number, roadWidth:Number):void
		{
			p.camera.x = (p.world.x || 0) - cameraX;
			p.camera.y = (p.world.y || 0) - cameraY;
			p.camera.z = (p.world.z || 0) - cameraZ;
			p.screen.scale = cameraDepth / p.camera.z;
			p.screen.x = Math.round((width / 2) + (p.screen.scale * p.camera.x * width / 2));
			p.screen.y = Math.round((height / 2) - (p.screen.scale * p.camera.y * height / 2));
			p.screen.w = Math.round((p.screen.scale * roadWidth * width / 2));
		}
		
		
		private static function rumbleWidth(projectedRoadWidth:Number, lanes:int):Number
		{
			return projectedRoadWidth / Math.max(6, 2 * lanes);
		}
		
		
		private static function laneMarkerWidth(projectedRoadWidth:Number, lanes:int):Number
		{
			return projectedRoadWidth / Math.max(32, 8 * lanes);
		}
		
		
		private static function interpolate(a:Number, b:Number, percent:Number):Number
		{
			return a + (b - a) * percent;
		}
		
		
		private static function randomInt(min:Number, max:Number):int
		{
			return Math.round(interpolate(min, max, Math.random()));
		}
		
		
		private static function randomChoice(a:Array):*
		{
			return a[randomInt(0, a.length - 1)];
		}
		
		
		private static function easeIn(a:Number, b:Number, percent:Number):Number
		{
			return a + (b - a) * Math.pow(percent, 2);
		}
		
		
		//private static function easeOut(a:Number, b:Number, percent:Number):Number
		//{
		//	return a + (b - a) * (1 - Math.pow(1 - percent, 2));
		//}
		
		
		private static function easeInOut(a:Number, b:Number, percent:Number):Number
		{
			return a + (b - a) * ((-Math.cos(percent * Math.PI) / 2) + 0.5);
		}
		
		
		private static function percentRemaining(n:Number, total:Number):Number
		{
			return (n % total) / total;
		}
		
		
		private static function overlap(x1:Number, w1:Number, x2:Number, w2:Number, percent:Number = 1.0):Boolean
		{
			var half:Number = percent / 2;
			var min1:Number = x1 - (w1 * half);
			var max1:Number = x1 + (w1 * half);
			var min2:Number = x2 - (w2 * half);
			var max2:Number = x2 + (w2 * half);
			return !((max1 < min2) || (min1 > max2));
		}
		
		
		private static function toInt(obj:*, def:*):int
		{
			if (obj != null)
			{
				var x:int = parseInt(obj, 10);
				if (!isNaN(x)) return x;
			}
			return toInt(def, 0);
		}
		
		
		private static function toFloat(obj:*, def:Number = NaN):Number
		{
			if (obj != null)
			{
				var x:Number = parseFloat(obj);
				if (!isNaN(x)) return x;
			}
			return toFloat(def, 0.0);
		}
		
		
		//-----------------------------------------------------------------------------------------
		// Render Functions
		//-----------------------------------------------------------------------------------------
		
		private function renderBackground(layer:BitmapData, offsetX:Number = 0.0, offsetY:Number = 0.0):void
		{
			//var sourceX:Number = 0 + Math.floor(layer.width * offsetX);
			//if (_isSteerLeft || _isSteerRight) Debug.trace(sourceX);
			_bgScroller.update(0);
			_renderBuffer.blitImage(_bgScroller, 0, 0, _bgScroller.width, _bgScroller.height);
		}
		
		
		private function renderSegment(x1:Number, y1:Number, w1:Number, x2:Number, y2:Number,
			w2:Number, haze:Number, color:ColorSet):void
		{
			var r1:Number = rumbleWidth(w1, _lanes),
				r2:Number = rumbleWidth(w2, _lanes),
				l1:Number = laneMarkerWidth(w1, _lanes),
				l2:Number = laneMarkerWidth(w2, _lanes),
				lanew1:Number, lanew2:Number, lanex1:Number, lanex2:Number, lane:int;
			
			/* Draw offroad area segment. */
			_renderBuffer.blitRect(0, y2, _bufferWidth, y1 - y2, haze < 1.0 ? mixColors(color.grass, COLORS.FOG, haze) : color.grass);
			
			/* Draw the road segment. */
			renderPolygon(x1 - w1 - r1, y1, x1 - w1, y1, x2 - w2, y2, x2 - w2 - r2, y2, color.rumble, haze);
			renderPolygon(x1 + w1 + r1, y1, x1 + w1, y1, x2 + w2, y2, x2 + w2 + r2, y2, color.rumble, haze);
			renderPolygon(x1 - w1, y1, x1 + w1, y1, x2 + w2, y2, x2 - w2, y2, color.road, haze);
			
			/* Draw lane strips. */
			if (color.lane)
			{
				lanew1 = w1 * 2 / _lanes;
				lanew2 = w2 * 2 / _lanes;
				lanex1 = x1 - w1 + lanew1;
				lanex2 = x2 - w2 + lanew2;
				for (lane = 1 ;lane < _lanes; lanex1 += lanew1, lanex2 += lanew2, lane++)
				{
					renderPolygon(lanex1 - l1 / 2, y1, lanex1 + l1 / 2, y1, lanex2 + l2 / 2, y2, lanex2 - l2 / 2, y2, color.lane, haze);
				}
			}
			
			/* Draw fog. */
			//if (haze < 1.0)
			//{
			//	_renderBuffer.drawRect(0, y1, _bufferWidth, y2 - y1, COLORS.FOG, 1.0 - haze);
			//}
		}
		
		
		private function renderPolygon(x1:Number, y1:Number, x2:Number, y2:Number,
			x3:Number, y3:Number, x4:Number, y4:Number, color:uint, haze:Number = 1.0):void
		{
			if (haze < 1.0)
			{
				color = mixColors(color, COLORS.FOG, haze);
			}
			
			_renderBuffer.drawPolygon(x1, y1, x2, y2, x3, y3, x4, y4, color);
		}
		
		
		private function renderPlayer(roadWidth:Number, speedPercent:Number, scale:Number,
			destX:int, destY:int, steer:Number, updown:Number):void
		{
			var bounce:Number = (1.5 * Math.random() * speedPercent * _resolution) * randomChoice([-1, 1]);
			var sprite:BitmapData;
			
			if (steer < 0)
			{
				sprite = (updown > 0) ? _sprites.PLAYER_UPHILL_LEFT : _sprites.PLAYER_LEFT;
			}
			else if (steer > 0)
			{
				sprite = (updown > 0) ? _sprites.PLAYER_UPHILL_RIGHT : _sprites.PLAYER_RIGHT;
			}
			else
			{
				sprite = (updown > 0) ? _sprites.PLAYER_UPHILL_STRAIGHT : _sprites.PLAYER_STRAIGHT;
			}
			
			renderSprite(roadWidth, sprite, scale, destX, destY + bounce, -0.5, -1);
		}
		
		
		private function renderSprite(roadWidth:Number, sprite:BitmapData, scale:Number,
			destX:int, destY:int, offsetX:Number, offsetY:Number, clipY:Number = 0):void
		{
			/* Scale for projection AND relative to roadWidth. */
			var destW:int = (sprite.width * scale * _bufferWidth / 2) * (_sprites.SCALE * roadWidth);
			var destH:int = (sprite.height * scale * _bufferWidth / 2) * (_sprites.SCALE * roadWidth);
			
			destX = destX + (destW * (offsetX || 0));
			destY = destY + (destH * (offsetY || 0));
			
			var clipH:int = clipY ? Math.max(0, destY + destH - clipY) : 0;
			
			if (clipH < destH)
			{
				//_renderBuffer.blitImage(sprite, destX, destY, destW, destH - clipH);
				_renderBuffer.drawImage(sprite, destX, destY, destW, destH - clipH, destW / sprite.width);
			}
		}
	}
}
