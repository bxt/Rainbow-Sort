fs = require('fs')
Canvas = require('canvas')

[width, height] = [400, 400]
[rectWidth, rectHeight] = [20, 20]

dir = __dirname + "/frames/"

# Initialised by reset().
colours = null
index = null
start = null
frame = null

timeouts = []
defer = (fn) ->
	saveFrame()
	fn()

# From Adam Bachman, https://gist.github.com/abachman/3716319
Colors =
	hslToRgb: (h, s, l) ->
		if s == 0
			r = g = b = l # achromatic
		else
			hue2rgb = (p, q, t) ->
				if t < 0 then t += 1
				if t > 1 then t -= 1
				if t < 1/6 then return p + (q - p) * 6 * t
				if t < 1/2 then return q
				if t < 2/3 then return p + (q - p) * (2/3 - t) * 6
				return p

			q = if l < 0.5 then l * (1 + s) else l + s - l * s
			p = 2 * l - q
			r = hue2rgb(p, q, h + 1/3)
			g = hue2rgb(p, q, h)
			b = hue2rgb(p, q, h - 1/3)

		[r * 255, g * 255, b * 255]


toHslString = (h) ->
	#"hsl(#{h}, 100%, 50%)"
	# hsl seems to be buggy for node-canvas?
	[r, g, b] = (Math.round(x) for x in Colors.hslToRgb(h/360, 1, 0.5))
	"rgb(#{r}, #{g}, #{b})"

saveFrame = ->
	path = dir + "frame#{("00000" + frame++)[-5..]}.png"
	fd = fs.openSync(path, 'w')
	canvas = drawColours()
	buffer = canvas.toBuffer()
	fs.writeSync(fd, buffer, 0, buffer.length, null)
	fs.closeSync(fd)
	console.log("saved png to #{path}")


drawColours = ->
	canvas = new Canvas(width, height)
	context = canvas.getContext('2d')

	for c in colours
			context.fillStyle = toHslString(c.hue)
			context.fillRect(c.x, c.y, rectWidth, rectHeight)

	canvas

initColours = ->
	for x in [0...width] by rectWidth
		for y in [0...height] by rectHeight
			val = Math.random()
			hue = Math.floor(256*val)
			colours.push({ val: val, hue: hue, x: x, y: y })


reset = ->

	colours = []
	index = 1
	frame = 0



	initColours()
	defer(sort)

swapRects = (ind1, ind2) ->
	val1 = colours[ind1]
	val2 = colours[ind2]

	swap = (field) ->
		tmp = val1[field]
		val1[field] = val2[field]
		val2[field] = tmp

	swap('val')
	swap('hue')


isort = ->
	for j in [index...0]
		swapRects(j - 1, j) if colours[j - 1].val > colours[j].val

	index++
	defer(isort) if index < colours.length

# Selection sort
# @author Bernhard Häussner (https://github.com/bxt)
ssort = ->
	min = index-1
	for j in [index...colours.length]
		min = j if colours[j].val < colours[min].val

	swapRects(index-1, min)

	index++
	defer(ssort) if index < colours.length

bsort = ->
	swapped = false
	for i in [1...colours.length]
		if colours[i - 1].val > colours[i].val
			swapRects(i - 1, i)
			swapped = true

	defer(bsort) if swapped

qsort = (tukey) ->
	# Put the median of colours.val's in colours[a].
	# Shamelessly stolen from Go's quicksort implementation.
	# See http://golang.org/src/pkg/sort/sort.go
	medianOfThree = (a, b, c) ->
		# Rename vars for clarity, as we want the median in a, not b.
		m0 = b
		m1 = a
		m2 = c

		# Bubble sort on colours[m0,m1,m2].val
		swapRects(m1, m0) if colours[m1].val < colours[m0].val
		swapRects(m2, m1) if colours[m2].val < colours[m1].val
		swapRects(m1, m0) if colours[m1].val < colours[m0].val

		# Now colours[m0].val <= colours[m1].val <= colours[m2].val

	getPivotInd = (from, to) ->
		# Do it this way to avoid overflow.
		mid = Math.floor(from + (to - from)/2)

		return mid if !tukey

		# Using Tukey's 'median of medians'
		# See http://www.johndcook.com/blog/2009/06/23/tukey-median-ninther/
		if to - from > 40
			s = Math.floor((to - from)/8)
			medianOfThree(from, from + s, from + 2 * s)
			medianOfThree(mid, mid - s, mid + s)
			medianOfThree(to - 1, to - 1 - s, to - 1 - 2 * s)

		medianOfThree(from, mid, to - 1)

		# We've put the median in from.
		return from

	partition = (from, to, pivotInd) ->
		pivot = colours[pivotInd].val
		# Put pivot at end for now.
		swapRects(pivotInd, to)

		pivotInd = from
		for i in [from...to]
			if colours[i].val <= pivot
				swapRects(i, pivotInd)
				pivotInd++

		# Swap 'em back.
		swapRects(pivotInd, to)

		return pivotInd

	doQsort = (from, to) ->
		return if from >= to

		pivotInd = getPivotInd(from, to)
		pivotInd = partition(from, to, pivotInd)

		defer(->
			doQsort(from, pivotInd - 1)
			doQsort(pivotInd + 1, to)
		)

	doQsort(0, colours.length - 1)

# Heapsort
# Based on this Java implementation: http://git.io/heapsort
# @author Bernhard Häussner (https://github.com/bxt)
hsort = ->
	# Let the browser render between steps using a call stack
	stack = []
	work = ->
		if stack.length
			stack.pop()() # execute stack top
			defer(work) # loop

	size = colours.length

	# Make branch from i downwards a proper max heap
	maxHeapify = (i) ->
		left = i*2 + 1
		right = i*2 + 2
		largest = i
		largest = left if left < size and colours[left].val > colours[i].val
		largest = right if right < size and colours[right].val > colours[largest].val
		if i isnt largest
			swapRects(i, largest)
			maxHeapify(largest)
			#stack.push(-> maxHeapify(largest))

	# Remove the top of the heap and move it behind the heap
	popMaxValue = ->
		size--
		swapRects(0, size)
		maxHeapify(0) if size > 0

	# Fill the call stack (reverse order)
	for i in [size-1 ... 0]
		stack.push(popMaxValue)
	for i in [0 .. size//2 - 1]
		do (i) ->
			stack.push(-> maxHeapify(i))

	do work

sort = hsort
reset()




