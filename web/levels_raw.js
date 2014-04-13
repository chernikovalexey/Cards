JSON.stringify({
  	levels: [{
	    name: "Transgalactic Hustler",
	    x: 0,
	    y: 0,
	    width: 1600,
	    height: 1200,
	    blocks: [100, 4],
	    from: {
	      	x: 100,
	      	y: 50
	    },
	    to: {
	      	x: 300,
	      	y: 125
	    },
	    obstacles: [{
	      	x: 0,
	      	y: 0,
	      	width: 1600,
	      	height: 10,
	      	type: 1
	    }]
  	}, {
  		name: 'Captain Asteroid',
  		x: 1600,
  		y: 0,
  		width: 1200,
  		height: 1000,
  		blocks: [40, 10],
  		from: {
  			x: 1600 + 100,
  			y: 0 + 20
  		},
  		to: {
  			x: 1600 + 400,
  			y: 0 + 45
  		},
  		obstacles: [{
  			x: 1600,
  			y: 10,
  			width: 1200,
  			height: 10,
  			type: 1
  		}]
  	}]
});