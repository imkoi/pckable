extends Node


const EMPTY_STATUS := 0
const LOADING_STATUS := 1
const LOADED_STATUS := 2
const RESPONSE_BODY_KEY := "body"

var _storage: PckableStorageRuntime
var _catalog_loading := Dictionary()
var _scene_tree: SceneTree
var _initializd: bool

var _http_requests_pool := Dictionary() # http_request to is_free
var max_http_requests_pool := 4
var http_timout := 10.0
var max_retries_count := 3
var retry_delay := 5.0


func _exit_tree() -> void:
	if _storage:
		_storage.free()


func load_manifest(manifest_json: StringName) -> bool:
	var json := JSON.new()
	var error := json.parse(manifest_json)
	
	if error != OK:
		push_error(error)
		
		return false
	
	var catalogs := json.data as Array
	
	return _storage.add_manifest(catalogs)


func load_resource(key: String,
 timeout_msec: int = 60000, use_cached: bool = true) -> Resource:
	_try_init()
	
	var bundle := await load_resources([key], timeout_msec, use_cached)
	
	if bundle.has(key):
		return bundle[key]
	
	return null


func load_resources(keys: PackedStringArray,
 timeout_msec: int = 60000, use_cached: bool = true) -> Dictionary:
	_try_init()
	
	var bundle := Dictionary()
	var timer := PckableTimer.create(timeout_msec)
	var catalog_names := PackedStringArray()
	var resources := PackedStringArray()
	
	resources.resize(keys.size())
	
	for i in keys.size():
		resources[i] = _storage.get_path_by_key(keys[i])
		var catalog_name := _storage.get_catalog_name_by_path(resources[i])
		
		if not catalog_names.has(catalog_name):
			catalog_names.push_back(catalog_name)
	
	for catalog_name in catalog_names:
		await _load_catalog(catalog_name, timer, use_cached)
		
		if timer.is_expired():
			return bundle
	
	return await _load_resources_internal(keys, resources, timer)


func _load_catalog(catalog_name: StringName, timer: PckableTimer, use_cached) -> bool:
	if _catalog_loading.has(catalog_name):
		while _catalog_loading[catalog_name] == LOADING_STATUS:
			await _scene_tree.process_frame
		
		if use_cached:
			if _catalog_loading[catalog_name] == LOADED_STATUS:
				return true
	
	_catalog_loading[catalog_name] = LOADING_STATUS
	
	if catalog_name.is_empty():
		_catalog_loading[catalog_name] = EMPTY_STATUS
		
		push_error("catalog name could not be empty")
		return false
	
	var catalog_address := _storage.get_catalog_address(catalog_name)
	
	if catalog_address.length() > 0 and catalog_address != "local":
		print("start downloading %s" % catalog_name)
		var url := catalog_address + "/" + catalog_name + ".pck"
		var pck_data := await _download_pck_data(url, timer)
		
		if timer.is_expired():
			_catalog_loading[catalog_name] = EMPTY_STATUS
			
			push_error("free request was not found in time")
			return false
		
		if pck_data.size() == 0:
			_catalog_loading[catalog_name] = EMPTY_STATUS
			
			push_error("downloaded empty catalog")
			return false
		
		var file_path := PckablePathUtility.get_executable_dir()
		file_path += catalog_name + ".pck"
		
		var file := FileAccess.open(file_path, FileAccess.WRITE_READ)
		
		file.store_buffer(pck_data)
	
	var pck_path := "user://%s.pck" % catalog_name
	var success := ProjectSettings.load_resource_pack(pck_path)
	
	if success:
		_catalog_loading[catalog_name] = LOADED_STATUS
	else:
		_catalog_loading[catalog_name] = EMPTY_STATUS
	
	return success


func _download_pck_data(url: String, timer: PckableTimer) -> PackedByteArray:
	var request_node := await _pull_http_request_node(timer)
	
	if not request_node:
		return PackedByteArray()
	
	var payload := Dictionary()
	var callback := _on_request_completed.bind(payload)
	var retries := max_retries_count + 1
	
	request_node.request_completed.connect(callback)
	
	while retries > 0 and not timer.is_expired():
		var request_index := max_retries_count - retries
		var delay := 0.0
		
		if request_index >= 0:
			var temp := retry_delay * 2.0 ** request_index
			delay = temp / 2.0 + randf_range(0.0, temp / 2)
		
		if delay > 0:
			await _scene_tree.create_timer(delay).timeout
		
		request_node.timeout = min(timer.get_time_left_sec(), http_timout)
		request_node.request(url)
		
		while not timer.is_expired() and not payload.has(RESPONSE_BODY_KEY):
			await _scene_tree.process_frame
		
		if timer.is_expired() or not payload.has(RESPONSE_BODY_KEY):
			return PackedByteArray()
		
		if not payload.body or payload.body.size() == 0:
			retries -= 1
	
	request_node.request_completed.disconnect(callback)
	
	return payload.body


func _pull_http_request_node(timer: PckableTimer) -> HTTPRequest:
	var free_request := get_free_request()
	
	if free_request:
		return free_request
	
	if _http_requests_pool.size() < max_http_requests_pool:
		free_request = HTTPRequest.new()
		add_child(free_request)
		_http_requests_pool[free_request] = false
	
	while not free_request and not timer.is_expired():
		await _scene_tree.process_frame
		
		free_request = get_free_request()
	
	return free_request


func get_free_request() -> HTTPRequest:
	for request in _http_requests_pool:
		if _http_requests_pool[request]:
			return request
	
	return null


func _load_resources_internal(keys: PackedStringArray,
 resources: PackedStringArray, timer: PckableTimer) -> Dictionary:
	var bundle := Dictionary()
	
	for resource in resources:
		ResourceLoader.load_threaded_request(resource, String(), false, 2)
	
	while not _all_resources_loaded(resources) and not timer.is_expired():
		await _scene_tree.process_frame
	
	if timer.is_expired():
		push_error("resource was not loaded in time")
		
		return bundle
	
	for i in resources.size():
		var resource := resources[i]
		
		match ResourceLoader.load_threaded_get_status(resource):
			0:
				push_error("invalid path %s" % resource)
			2: 
				push_error("load path failed %s" % resource)
			_:
				bundle[keys[i]] = ResourceLoader.load_threaded_get(resource)
	
	return bundle


func _all_resources_loaded(resources: PackedStringArray) -> bool:
	var loaded_resources := 0
	
	for resource in resources:
		if ResourceLoader.load_threaded_get_status(resource) != LOADING_STATUS:
			loaded_resources += 1
	
	return loaded_resources == resources.size()


func _on_request_completed(result: int, response_code: int,
 headers: PackedStringArray, body: PackedByteArray, status: Dictionary):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("wrong result code received %s" % result)
	
	if response_code < 200 or response_code > 299:
		push_error("wrong response code received %s" % response_code)
	
	status[RESPONSE_BODY_KEY] = body


func _try_init() -> void:
	if not _initializd:
		_storage = PckableStorageRuntime.new()
		_storage.setup()
		_scene_tree = get_tree()
		
		_initializd = true
