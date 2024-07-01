extends Node


const pckables_operations: Dictionary = {};
var storage: PckableStorage;
var http_requests_pool: Dictionary = {}; # http_request to is_free
var max_http_requests_pool: int = 4;


func _exit_tree() -> void:
	if storage:
		storage.free();


func load_catalog(catalog_name: StringName, timeout_msec: int = 60000) -> bool:
	if not storage:
		storage = PckableStorage.new();
		storage.setup()

	var catalog_address := storage.get_catalog_address(catalog_name)
	
	print(catalog_address)
	
	if catalog_address.length() > 0 and catalog_address != "local":
		print("start downloading %s" % catalog_name)
		var url = catalog_address + "/" + catalog_name + ".pck"
		var pck_data := await download_pck_data(url, timeout_msec)
		
		if pck_data.size() == 0:
			push_error("downloaded empty catalog")
			return false
		
		var file_path = PckablePathUtility.get_project_path()
		file_path += catalog_name + ".pck"
		
		var file := FileAccess.open(file_path, FileAccess.WRITE_READ)
		
		file.store_buffer(pck_data)
		file.close()
	
	var pck_path = "res://%s.pck" % catalog_name
	
	return ProjectSettings.load_resource_pack(pck_path)


func download_pck_data(url: String, timeout_msec: int) -> PackedByteArray:
	var start_usec := Time.get_ticks_usec()
	var request_node := await pull_http_request_node(timeout_msec);
	
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


func _on_request_completed(result: int, response_code: int,
 headers: PackedStringArray, body: PackedByteArray, status: Dictionary):
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("wrong result code received %s" % result)
	
	if response_code < 200 or response_code > 299:
		push_error("wrong response code received %s" % response_code)
	
	status["result"] = body


func pull_http_request_node(timeout_msec: int) -> HTTPRequest:
	var start_time_usec = Time.get_ticks_usec()
	
	for request_to_is_free in http_requests_pool:
		var request := request_to_is_free["request"] as HTTPRequest
		
		if request_to_is_free["is_free"]:
			return request
	
	if http_requests_pool.size() < max_http_requests_pool:
		var request := HTTPRequest.new()
		add_child(request)
		http_requests_pool[request] = false
		
		return request
	
	var main_loop := Engine.get_main_loop()
	
	while (Time.get_ticks_usec() - start_time_usec) / 1000.0 < timeout_msec:
		await main_loop.process_frame
		
		for request_to_is_free in http_requests_pool:
			var request := request_to_is_free["request"] as HTTPRequest
			
			if request_to_is_free["is_free"]:
				return request
	
	push_error("Pull node was timeouted")
	
	return null
