; fast_walk: direction 0/1 becomes a signed -2/+2 pixel displacement (six bytes).
	add a, a
	dec a
	add a, a
	add a, (iy+4)
