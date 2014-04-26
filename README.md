Basic visualisation of various sort algorithms using HTML 5 canvas.

This is a version which will save the output to files using node.js instead of displaying it in a browser canvas. Uses [node-canvas](https://github.com/learnboost/node-canvas).

To convert to a movie you can use something like this:

     ffmpeg -i frames/frame%05d.png -c:v libx264 -pix_fmt yuv420p out.mp4

