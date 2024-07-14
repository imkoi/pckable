extends Node


const LOADING_STATUS := 1
const catalog_loading_status: Dictionary = {};

var _storage: PckableStorageRuntime;
var _http_requests_pool: Dictionary = {}; # http_request to is_free
var max_http_requests_pool: int = 4;


func _exit_tree() -> void:
	if _storage:
		_storage.free();


func load_manifest(manifest_json: StringName) -> bool:
	var json := JSON.new()
	var error := json.parse(manifest_json)
	
	if error != OK:
		push_error(error)
		
		return false
	
	var catalogs = json.data as Array
	
	return _storage.add_manifest(catalogs)


func load_resource(key: String, timeout_msec: int = 60000) -> Resource:
	_try_init()
	
	var path := _storage.get_path_by_key(key)
	var catalog_name := _storage.get_catalog_name_by_path(path)

	await _load_catalog(catalog_name, timeout_msec)
	
	var main_loop = Engine.get_main_loop();
	
	ResourceLoader.load_threaded_request(path, "", false, 2)

	while ResourceLoader.load_threaded_get_status(path) == LOADING_STATUS:
		await main_loop.process_frame
	
	match ResourceLoader.load_threaded_get_status(path):
		0:
			push_error("invalid path %s" % path)
			return null
		2: 
			push_error("load path failed %s" % path)
			return null
	
	return ResourceLoader.load_threaded_get(path)


func load_resources(keys: PackedStringArray,
 timeout_msec: int = 60000) -> Dictionary:
	_try_init()
	
	var catalogs_to_load := PackedStringArray()
	var paths := PackedStringArray()
	
	paths.resize(keys.size())
	
	for i in keys.size():
		paths[i] = _storage.get_path_by_key(keys[i])
		var catalog_name := _storage.get_catalog_name_by_path(paths[i])
		
		if not catalogs_to_load.has(catalog_name):
			catalogs_to_load.push_back(catalog_name)
	
	for catalog_name in catalogs_to_load:
		await _load_catalog(catalog_name, timeout_msec)
	
	var main_loop = Engine.get_main_loop();
	
	for path in paths:
		ResourceLoader.load_threaded_request(path, "", false, 2)
	
	while not _all_resources_loaded(paths):
		await main_loop.process_frame

	var results := {}
	
	for i in paths.size():
		var path := paths[i]
		
		match ResourceLoader.load_threaded_get_status(path):
			0:
				push_error("invalid path %s" % path)
			2: 
				push_error("load path failed %s" % path)
			_:
				results[keys[i]] = ResourceLoader.load_threaded_get(path)
	
	return results


func _all_resources_loaded(paths: PackedStringArray) -> bool:
	var loaded_resources := 0
	
	for path in paths:
		if ResourceLoader.load_threaded_get_status(path) != LOADING_STATUS:
			loaded_resources += 1
	
	return loaded_resources == paths.size()


func _load_catalog(catalog_name: StringName,
 timeout_msec: int = 60000) -> bool:
	if catalog_name.length() == 0:
		push_error("catalog name could not be empty")
		return false
	
	var catalog_address := _storage.get_catalog_address(catalog_name)
	
	if catalog_address.length() > 0 and catalog_address != "local":
		print("start downloading %s" % catalog_name)
		var url = catalog_address + "/" + catalog_name + ".pck"
		var pck_data := await _download_pck_data(url, timeout_msec)
		
		if pck_data.size() == 0:
			push_error("downloaded empty catalog")
			return false
		
		var file_path = PckablePathUtility.get_executable_dir()
		file_path += catalog_name + ".pck"
		
		var file := FileAccess.open(file_path, FileAccess.WRITE_READ)
		
		file.store_buffer(pck_data)
		file.close()
	
	var pck_path = "res://%s.pck" % catalog_name
	
	return ProjectSettings.load_resource_pack(pck_path)


func _download_pck_data(url: String, timeout_msec: int) -> PackedByteArray:
	var start_usec := Time.get_ticks_usec()
	var request_node := await _pull_http_request_node(timeout_msec);
	
	if not request_node:
		return PackedByteArray()
	
	var main_loop = Engine.get_main_loop();
	var payload = Dictionary()
	var callback = _on_request_completed.bind(payload)
	var time_spent_msec := (Time.get_ticks_usec() - start_usec) / 1000.0
	
	request_node.request_completed.connect(callback);
	request_node.timeout = (timeout_msec - time_spent_msec) / 1000.0
	request_node.request(url);
	
	while not payload.has("result"):
		await main_loop.process_frame
	
	return payload.result


func _pull_http_request_node(timeout_msec: int) -> HTTPRequest:
	var start_time_usec = Time.get_ticks_usec()
	
	for request_to_is_free in _http_requests_pool:
		var request := request_to_is_free["request"] as HTTPRequest
		
		if request_to_is_free["is_free"]:
			return request
	
	if _http_requests_pool.size() < max_http_requests_pool:
		var request := HTTPRequest.new()
		add_child(request)
		_http_requests_pool[request] = false
		
		return request
	
	var main_loop := Engine.get_main_loop()
	
	while (Time.get_ticks_usec() - start_time_usec) / 1000.0 < timeout_msec:
		await main_loop.process_frame
		
		for request_to_is_free in _http_requests_pool:
			var request := request_to_is_free["request"] as HTTPRequest
			
			if request_to_is_free["is_free"]:
				return request
	
	push_error("Pull node was timeouted")
	
	return null


func _on_request_completed(result: int, response_code: int,
 headers: PackedStringArray, body: PackedByteArray, status: Dictionary):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("wrong result code received %s" % result)
	
	if response_code < 200 or response_code > 299:
		push_error("wrong response code received %s" % response_code)
	
	status["result"] = body


func _try_init() -> void:
	if not _storage:
		_storage = PckableStorageRuntime.new();
		_storage.setup()
