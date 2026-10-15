/**
 * Created by Alex Bol on 9/8/2017.
 */
'use strict';

import { expect } from 'chai';
import Flatten, {Arc} from '../../index';

import {Box, Point, Segment} from '../../index';

describe('#Flatten.Box', function() {
    it('May create new instance of Box', function () {
        let box = new Box();
        expect(box).to.be.an.instanceof(Box);
    });
    it('Method intersect returns true if two boxes intersected', function () {
        let box1 = new Box(1, 1, 3, 3);
        let box2 = new Box(-3, -3, 2, 2);
        expect(box1.intersect(box2)).to.equal(true);
    });
    it('Method expand expands current box with other', function () {
        let box1 = new Box(1, 1, 3, 3);
        let box2 = new Box(-3, -3, 2, 2);
        expect(box1.merge(box2)).to.deep.equal({xmin:-3, ymin:-3, xmax:3, ymax:3});
    });
    it('Method contains correctly marks arc as contained in box', function () {
        let box = new Box(0, 0, 10, 10);
        let arc = new Arc(new Point(1, 1), 1, 0, Math.PI / 4, true);
        expect(box.contains(arc)).to.equal(true);
    });
    it('Method contains correctly marks arc as not contained in box (fully outside)', function () {
        let box = new Box(0, 0, 10, 10);
        let arc = new Arc(new Point(20, 20), 1, 0, Math.PI / 4, false);
        expect(box.contains(arc)).to.equal(false);
    });
    it('Method contains correctly marks arc as not contained in box (middle of arc partly outside)', function () {
        let box = new Box(0, 0, 10, 10);
        let arc = new Arc(new Point(1, 1), 10, 0, Math.PI / 4, false);
        expect(box.contains(arc)).to.equal(false);
    });
    it('Method contains correctly marks arc as not contained in box (endpoint of arc outside)', function () {
        let box = new Box(0, 0, 10, 10);
        let arc = new Arc(new Point(11, 11), 5, Math.PI, Math.PI / 2 * 3, false);
        expect(box.contains(arc)).to.equal(false);
    });
    it('Method svg() without parameters creates svg string with default attributes', function() {
        let box = new Box(-30, -30, 20, 20);
        let svg = box.svg();
        expect(svg.search("stroke")).to.not.equal(-1);
    });
    it('Method svg() with extra parameters may add additional attributes', function() {
        let box = new Box(-30, -30, 20, 20);
        let svg = box.svg({fill: "red", fillOpacity: 0.4, id:"123",className:"name"});
        expect(svg.search("stroke")).to.not.equal(-1);
        expect(svg.search("id")).to.not.equal(-1);
        expect(svg.search("class")).to.not.equal(-1);
    })
    it('Can measure distance to box', function() {
        let box = new Box(-30, -30, 20, 20);
        let pt = new Point(30, 0)
        const [dist, shortest_segment] = box.distanceTo(pt)
        expect(dist).to.be.equal(10);
        expect(shortest_segment).to.be.deep.equal({ps: {x: 20, y: 0}, pe: {x:30, y: 0}});
    });
    describe('distanceTo(Box) (issue #210)', function () {
        it('returns zero for boxes with intersecting boundaries', function () {
            const a = new Box(11.997102737426758, 6.649463176727295, 13.695880889892578, 7.980637073516846);
            const b = new Box(13.374691009521484, 6.007083415985107, 15.073468208312988, 7.338257312774658);

            expect(a.distanceTo(b)[0]).to.equal(0);
        });
        it('returns the boundary gap for disjoint boxes', function () {
            const a = new Box(0, 0, 1, 1);
            const b = new Box(3, 0, 4, 1);
            const [dist, shortest_segment] = a.distanceTo(b);

            expect(dist).to.equal(2);
            expect(shortest_segment).to.deep.equal({ps: {x: 1, y: 0}, pe: {x: 3, y: 0}});
        });
        it('returns a shortest segment from the calling box to the other box', function () {
            const a = new Box(0, 0, 1, 1);
            const b = new Box(3, 0, 4, 1);
            const [, shortest_segment] = a.distanceTo(b);

            expect(shortest_segment.ps).to.deep.include({x: 1, y: 0});
            expect(shortest_segment.pe).to.deep.include({x: 3, y: 0});
        });
        it('supports Segment.distanceTo(Box)', function () {
            const segment = new Segment(new Point(-2, 0.5), new Point(-1, 0.5));
            const box = new Box(0, 0, 1, 1);
            const [dist, shortest_segment] = segment.distanceTo(box);

            expect(dist).to.equal(1);
            expect(shortest_segment.ps).to.deep.include({x: -1, y: 0.5});
            expect(shortest_segment.pe).to.deep.include({x: 0, y: 0.5});
        });
    });
});
