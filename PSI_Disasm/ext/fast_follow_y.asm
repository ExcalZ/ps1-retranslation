; fast_walk: direction 0/1 becomes -2/+2 pixels; padding keeps the stock seven bytes.
	add a, a
	dec a
	add a, a
	nop
	add a, (iy+2)
