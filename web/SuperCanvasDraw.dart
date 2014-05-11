// Copyright 2012 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/**
 * Draws using the given canvas context for debugging purposes.
 * WARNING: This implementation modifies its arguments (e.g. Vectors) to save
 * garbage.
 */
// TODO(gregbglw): Test all of these methods to make sure that they draw the
// correct things.

import 'package:box2d/box2d_browser.dart';
import "dart:html";
import "Color4.dart";

class SuperCanvasDraw {
/** The canvas rendering context with which to draw. */

/// draw shapes
    static const int e_shapeBit = 0x0001;
/// draw joint connections
    static const int e_jointBit = 0x0002;
/// draw core (TimeOfImpact) shapes
    static const int e_aabbBit = 0x0004;
/// draw axis aligned boxes
    static const int e_pairBit = 0x0008;
/// draw center of mass
    static const int e_centerOfMassBit = 0x0010;
/// draw dynamic tree.
    static const int e_dynamicTreeBit = 0x0020;
/// draw with lines (vs. default filled polygons).
    static const int e_lineDrawingBit = 0x0040;

    CanvasRenderingContext2D ctx;
    int flags;
    ViewportTransform viewportTransform;

    SuperCanvasDraw(ViewportTransform viewport, this.ctx) {
        flags = e_shapeBit;
        viewportTransform = viewport;
        assert (null != viewport && null != ctx);
    }

/**
   * Draw a closed polygon provided in CCW order. WARNING: This mutates
   * [vertices].
   */
    void drawPolygon(List<Vector2> vertices, int vertexCount, Color4 color) {
        _pathPolygon(vertices, vertexCount, color);
        ctx.stroke();
    }

/**
   * Draw a solid closed polygon provided in CCW order. WARNING: This mutates
   * [vertices].
   */
    void drawSolidPolygon(List<Vector2> vertices, int vertexCount, Color4 color) {
        _pathPolygon(vertices, vertexCount, color);
        ctx.fill();
    }

    void _pathPolygon(List<Vector2> vertices, int vertexCount, Color4 color) {
// Set the color and convert to screen coordinates.
        _color = color;
// TODO(gregbglw): Do a single ctx transform rather than convert all of
// these vectors.
        for (int i = 0; i < vertexCount; ++i)
            getWorldToScreenToOut(vertices[i], vertices[i]);

        ctx.beginPath();
        ctx.moveTo(vertices[0].x, vertices[0].y);

// Draw lines to all of the remaining points.
        for (int i = 1; i < vertexCount; ++i)
            ctx.lineTo(vertices[i].x, vertices[i].y);

// Draw a line back to the starting point.
        ctx.lineTo(vertices[0].x, vertices[0].y);

// Close the drawn polygon ready for fill/stroke
        ctx.closePath();
    }

/** Draw a line segment. WARNING: This mutates [p1] and [p2]. */
    void drawSegment(Vector2 p1, Vector2 p2, Color4 color) {
        _color = color;
        getWorldToScreenToOut(p1, p1);
        getWorldToScreenToOut(p2, p2);

        ctx.beginPath();
        ctx.moveTo(p1.x, p1.y);
        ctx.lineTo(p2.x, p2.y);
        ctx.closePath();
        ctx.stroke();
    }

/** Draw a circle. WARNING: This mutates [center]. */
    void drawCircle(Vector2 center, num radius, Color4 color, [Vector2 axis]) {
        radius *= viewportTransform.scale;
        _pathCircle(center, radius, color);
        ctx.stroke();
    }

/** Draw a solid circle. WARNING: This mutates [center]. */
    void drawSolidCircle(Vector2 center, num radius, Color4 color, [Vector2 axis]) {
        radius *= viewportTransform.scale;
        drawPoint(center, radius, color);
    }

/**
   * Draws the given point with the given *unscaled* radius, in the given [color].
   * WARNING: This mutates [point].
   */
    void drawPoint(Vector2 point, num radiusOnScreen, Color4 color) {
        _pathCircle(point, radiusOnScreen, color);
        ctx.fill();
    }

    void _pathCircle(Vector2 center, num radius, Color4 color) {
        _color = color;
        getWorldToScreenToOut(center, center);

        ctx.beginPath();
        ctx.arc(center.x, center.y, radius, 0, MathBox.TWO_PI, true);
        ctx.closePath();
    }

/**
   * Draw a transform. Choose your own length scale. WARNING: This mutates
   * [xf.position].
   */
    void drawTransform(Transform xf, Color4 color) {
        drawCircle(xf.position, 0.1, color);
// TODO(rupertk): Draw rotation representation (drawCircle axis parameter?)
    }

/** Draw a string. */
    void drawString(num x, num y, String s, Color4 color) {
        _color = color;

        ctx.strokeText(s, x, y);
    }

/** Sets the rendering context stroke and fill color to [color]. */
    void set _color(Color4 color) {
        ctx.setStrokeColorRgb(color.x, color.y, color.z, color.a);
        ctx.setFillColorRgb(color.x, color.y, color.z, color.a);
    }

/**
   * Sets the center of the viewport to the given x and y values and the
   * viewport scale to the given scale.
   */
    void setCamera(num x, num y, num scale) {
        viewportTransform.setCamera(x,y,scale);
    }



/**
   * Screen coordinates are specified in argScreen. These coordinates are
   * converted to World coordinates and placed in the argWorld return vector.
   */
    void getScreenToWorldToOut(Vector2 argScreen, Vector2 argWorld) {
        viewportTransform.getScreenToWorld(argScreen, argWorld);
    }

/**
   * World coordinates are specified in argWorld. These coordinates are
   * converted to screen coordinates and placed in the argScreen return vector.
   */
    void getWorldToScreenToOut(Vector2 argWorld, Vector2 argScreen) {
        viewportTransform.getWorldToScreen(argWorld, argScreen);
    }
}
