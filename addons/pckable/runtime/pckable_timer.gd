class_name PckableTimer extends RefCounted

var start_time_usec : int
var timeout_usec : int

static func create(timeout_msec: int) -> PckableTimer:
	var timer := PckableTimer.new()
	
	timer.start_time_usec = Time.get_ticks_usec()
	timer.timeout_usec = timeout_msec * 1000
	
	return timer

func is_expired() -> bool:
	return get_time_left_usec() <= 0


func get_time_left_sec() -> float:
	return get_time_left_msec() / 1000.0


func get_time_left_msec() -> float:
	return get_time_left_usec() / 1000.0


func get_time_left_usec() -> float:
	return timeout_usec - (Time.get_ticks_usec() - start_time_usec)
