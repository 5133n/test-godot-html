GDPC                �                                                                         T   res://.godot/exported/133200997/export-28d74bcfaeb4b0ca75c8bfcbf615d89f-client.scn  #      �      E�OR8�|��VR�    P   res://.godot/exported/133200997/export-59f5893cf12fc754877ad92fe5b9f384-chat.scn0            �\x9q/�y{���    T   res://.godot/exported/133200997/export-753b2295faba52a01a8aa2a973e9096c-combo.scn   �)      �      �bv_L-em�}�)<�    T   res://.godot/exported/133200997/export-c89a2950482f3a432bab03a0591e8d28-server.scn  G      �      �Y�6('CImq�+MA    ,   res://.godot/global_script_class_cache.cfg  `�      #      �|n[��h���\�2G    d   res://.godot/imported/WebSocket Chat Demo.apple-touch-icon.png-709f2ca028ff86ef92976b999caf8b28.ctex�M      �(      ��A��"�C�X��    X   res://.godot/imported/WebSocket Chat Demo.icon.png-158243a759e0120c7795fe5dfa1c6669.ctex�w             O�ޖ��g��p�    T   res://.godot/imported/WebSocket Chat Demo.png-9a74e8cea2168875a4039ff9ffae7069.ctex ��      -      �%�$����<�׿�+    H   res://.godot/imported/icon.webp-e94f9a68b0f625a567a797079e4d325f.ctex   �.             O�ޖ��g��p�       res://.godot/uid_cache.bin  ��      !      &��C�ԗL����P    8   res://WebSocket Chat Demo.apple-touch-icon.png.import   �v      �       !��,��A�X=؊�v    ,   res://WebSocket Chat Demo.icon.png.import   Ј      �       �M?��<�Gح6>�&m    $   res://WebSocket Chat Demo.png.importж      �       VE`�F%:Wxpl       res://chat.tscn.remap   ��      a       ��n�D&��qh����       res://client.gd P      �      ��-�0�S��꿃��       res://client.tscn.remap �      c       ��i�"z��Bg>Gr�q       res://combo.tscn.remap  ��      b       �9�Sᣞ�++�K�,       res://icon.webp ��            vo/��ɭ�f+��3X�       res://icon.webp.import  �?      �       L�K��W����Yl	��       res://project.binary��      �      +�ιN�'ۚ�@�x�       res://server.gd �@      D      �g׊�/WKY�el3���       res://server.tscn.remap �      c       6�]��U�s;�i*�v�    $   res://websocket/WebSocketClient.gd          �      �4�k:��)�#�ɜ�M    $   res://websocket/WebSocketServer.gd  �      x      H׷6�-?�5���        extends Node
class_name WebSocketClient

@export var handshake_headers: PackedStringArray
@export var supported_protocols: PackedStringArray
var tls_options: TLSOptions = null


var socket = WebSocketPeer.new()
var last_state = WebSocketPeer.STATE_CLOSED


signal connected_to_server()
signal connection_closed()
signal message_received(message: Variant)


func connect_to_url(url) -> int:
	socket.supported_protocols = supported_protocols
	socket.handshake_headers = handshake_headers
	var err = socket.connect_to_url(url, tls_options)
	if err != OK:
		return err
	last_state = socket.get_ready_state()
	return OK


func send(message) -> int:
	if typeof(message) == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))


func get_message() -> Variant:
	if socket.get_available_packet_count() < 1:
		return null
	var pkt = socket.get_packet()
	if socket.was_string_packet():
		return pkt.get_string_from_utf8()
	return bytes_to_var(pkt)


func close(code := 1000, reason := "") -> void:
	socket.close(code, reason)
	last_state = socket.get_ready_state()


func clear() -> void:
	socket = WebSocketPeer.new()
	last_state = socket.get_ready_state()


func get_socket() -> WebSocketPeer:
	return socket


func poll() -> void:
	if socket.get_ready_state() != socket.STATE_CLOSED:
		socket.poll()
	var state = socket.get_ready_state()
	if last_state != state:
		last_state = state
		if state == socket.STATE_OPEN:
			connected_to_server.emit()
		elif state == socket.STATE_CLOSED:
			connection_closed.emit()
	while socket.get_ready_state() == socket.STATE_OPEN and socket.get_available_packet_count():
		message_received.emit(get_message())


func _process(delta):
	poll()
     extends Node
class_name WebSocketServer

signal message_received(peer_id: int, message)
signal client_connected(peer_id: int)
signal client_disconnected(peer_id: int)

@export var handshake_headers := PackedStringArray()
@export var supported_protocols: PackedStringArray
@export var handshake_timout := 3000
@export var use_tls := false
@export var tls_cert: X509Certificate
@export var tls_key: CryptoKey
@export var refuse_new_connections := false:
	set(refuse):
		if refuse:
			pending_peers.clear()


class PendingPeer:
	var connect_time: int
	var tcp: StreamPeerTCP
	var connection: StreamPeer
	var ws: WebSocketPeer

	func _init(p_tcp: StreamPeerTCP):
		tcp = p_tcp
		connection = p_tcp
		connect_time = Time.get_ticks_msec()


var tcp_server := TCPServer.new()
var pending_peers: Array[PendingPeer] = []
var peers: Dictionary


func listen(port: int) -> int:
	assert(not tcp_server.is_listening())
	return tcp_server.listen(port)


func stop():
	tcp_server.stop()
	pending_peers.clear()
	peers.clear()


func send(peer_id, message) -> int:
	var type = typeof(message)
	if peer_id <= 0:
		# Send to multiple peers, (zero = brodcast, negative = exclude one)
		for id in peers:
			if id == -peer_id:
				continue
			if type == TYPE_STRING:
				peers[id].send_text(message)
			else:
				peers[id].put_packet(message)
		return OK

	assert(peers.has(peer_id))
	var socket = peers[peer_id]
	if type == TYPE_STRING:
		return socket.send_text(message)
	return socket.send(var_to_bytes(message))


func get_message(peer_id) -> Variant:
	assert(peers.has(peer_id))
	var socket = peers[peer_id]
	if socket.get_available_packet_count() < 1:
		return null
	var pkt = socket.get_packet()
	if socket.was_string_packet():
		return pkt.get_string_from_utf8()
	return bytes_to_var(pkt)


func has_message(peer_id) -> bool:
	assert(peers.has(peer_id))
	return peers[peer_id].get_available_packet_count() > 0


func _create_peer() -> WebSocketPeer:
	var ws = WebSocketPeer.new()
	ws.supported_protocols = supported_protocols
	ws.handshake_headers = handshake_headers
	return ws


func poll() -> void:
	if not tcp_server.is_listening():
		return
	while not refuse_new_connections and tcp_server.is_connection_available():
		var conn = tcp_server.take_connection()
		assert(conn != null)
		pending_peers.append(PendingPeer.new(conn))
	var to_remove := []
	for p in pending_peers:
		if not _connect_pending(p):
			if p.connect_time + handshake_timout < Time.get_ticks_msec():
				# Timeout
				to_remove.append(p)
			continue # Still pending
		to_remove.append(p)
	for r in to_remove:
		pending_peers.erase(r)
	to_remove.clear()
	for id in peers:
		var p: WebSocketPeer = peers[id]
		var packets = p.get_available_packet_count()
		p.poll()
		if p.get_ready_state() != WebSocketPeer.STATE_OPEN:
			client_disconnected.emit(id)
			to_remove.append(id)
			continue
		while p.get_available_packet_count():
			message_received.emit(id, get_message(id))
	for r in to_remove:
		peers.erase(r)
	to_remove.clear()


func _connect_pending(p: PendingPeer) -> bool:
	if p.ws != null:
		# Poll websocket client if doing handshake
		p.ws.poll()
		var state = p.ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			var id = randi_range(2, 1 << 30)
			peers[id] = p.ws
			client_connected.emit(id)
			return true # Success.
		elif state != WebSocketPeer.STATE_CONNECTING:
			return true # Failure.
		return false # Still connecting.
	elif p.tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return true # TCP disconnected.
	elif not use_tls:
		# TCP is ready, create WS peer
		p.ws = _create_peer()
		p.ws.accept_stream(p.tcp)
		return false # WebSocketPeer connection is pending.
	else:
		if p.connection == p.tcp:
			assert(tls_key != null and tls_cert != null)
			var tls = StreamPeerTLS.new()
			tls.accept_stream(p.tcp, TLSOptions.server(tls_key, tls_cert))
			p.connection = tls
		p.connection.poll()
		var status = p.connection.get_status()
		if status == StreamPeerTLS.STATUS_CONNECTED:
			p.ws = _create_peer()
			p.ws.accept_stream(p.connection)
			return false # WebSocketPeer connection is pending.
		if status != StreamPeerTLS.STATUS_HANDSHAKING:
			return true # Failure.
		return false


func _process(delta):
	poll()
        RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script           local://PackedScene_jy34x �          PackedScene          	         names "         Chat    layout_mode    anchors_preset    anchor_right    anchor_bottom    grow_horizontal    grow_vertical    size_flags_horizontal    size_flags_vertical    Control    Panel    VBoxContainer    Listen    HBoxContainer    Connect    Host    text    placeholder_text 	   LineEdit    toggle_mode    Button    Port 
   min_value 
   max_value    value    SpinBox    Send    RichTextLabel    	   variants                        �?                   ws://localhost:8000/test/       ws://my.server/path/             Connect     �G     �E      Listen       Enter some text to send...       Send       node_count             nodes     �   ��������	       ����                                                                  
   
   ����                                                  ����                                                  ����                          ����                          ����                                             ����                                      ����                  	      
                    ����                                      ����             	             ����                          	             ����                                ����                          conn_count              conns               node_paths              editable_instances              version             RSRC      extends Control

@onready var _client: WebSocketClient = $WebSocketClient
@onready var _log_dest = $Panel/VBoxContainer/RichTextLabel
@onready var _line_edit = $Panel/VBoxContainer/Send/LineEdit
@onready var _host = $Panel/VBoxContainer/Connect/Host

func info(msg):
	print(msg)
	_log_dest.add_text(str(msg) + "\n")


# Client signals
func _on_web_socket_client_connection_closed():
	var ws = _client.get_socket()
	info("Client just disconnected with code: %s, reson: %s" % [ws.get_close_code(), ws.get_close_reason()])


func _on_web_socket_client_connected_to_server():
	info("Client just connected with protocol: %s" % _client.get_socket().get_selected_protocol())


func _on_web_socket_client_message_received(message):
	info("%s" % message)


# UI signals.
func _on_send_pressed():
	if _line_edit.text == "":
		return

	info("Sending message: %s" % [_line_edit.text])
	_client.send(_line_edit.text)
	_line_edit.text = ""


func _on_connect_toggled(pressed):
	if not pressed:
		_client.close()
		return
	if _host.text == "":
		return
	info("Connecting to host: %s." % [_host.text])
	var err = _client.connect_to_url(_host.text)
	if err != OK:
		info("Error connecting to host: %s" % [_host.text])
		return
      RSRC                    PackedScene            ��������                                                  Panel    VBoxContainer    Connect    Send    resource_local_to_scene    resource_name 	   _bundled    script       PackedScene    res://chat.tscn �?g?
;Z   Script    res://client.gd ��������   Script #   res://websocket/WebSocketClient.gd ��������      local://PackedScene_pbehx �         PackedScene          
         names "         Client    script    WebSocketClient    supported_protocols    Node    Panel    layout_mode    anchors_preset    VBoxContainer    Listen    Connect    Host    Port    visible    Send 	   LineEdit    RichTextLabel *   _on_web_socket_client_connected_to_server    connected_to_server (   _on_web_socket_client_connection_closed    connection_closed '   _on_web_socket_client_message_received    message_received    _on_connect_toggled    toggled    _on_send_pressed    pressed    	   variants                                   "      
   demo-chat                          node_count             nodes     <   �����������    ����                          ����                           ���  ����                          ���  ����                      @    ���  ����                @    ���	  ����                   conn_count             conns     #                                                                             @                       @                           node_paths                                                                   editable_instances              base_scene              version             RSRC              RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       PackedScene    res://server.tscn �P���E1   PackedScene    res://client.tscn �@"�CC�      local://PackedScene_fcjrl <         PackedScene          	         names "         Combo    layout_mode    anchors_preset    anchor_right    anchor_bottom    grow_horizontal    grow_vertical    mouse_filter    Control    Box    HBoxContainer    Server    VBoxContainer    size_flags_horizontal    Client    Client2    Client3    	   variants                        �?                                            node_count             nodes     U   ��������       ����                                                          
   	   ����                                            ���                                ����                           ���                          ���                          ���                         conn_count              conns               node_paths              editable_instances              version             RSRC              GST2   �   �      ����               � �        �  RIFF�  WEBPVP8L�  /�����^""""J�������WY���՝�����g���0�efffffffjzK����+�eɶ�H������ᏩQi�IY�P��	I�$G�����NeuW�9i���m���j0��.�Q6̵(5��e��P��6�$��I��>&�o����ڴ��xvw�mv���w��A'8�w��
��!5�ϓ_���%��$���ՙ�$K��-/E:ql##A���m���&	6���Ⱛ��$7�I�]Wx���7��骈�e)�bա��-�L�ܞ��Aj�J-R�W�Z�vH���=��Unu(r�Z7�tO鞶Q(�t��R2���J��(���Z6�� %3!5Z6ײ��7�*��H�P�ZuU�p�tB��J�$��-�u�X��c]h�P��O�]&��t�P屔G�J��l�cUF�x�%*�/��]	�J=���1�i��*+�V���ԃ�j�UU>s%{f���a��ժ򙍚?��OH�ˍU�R�.5���)����h;��A7��@v�Qm��*KG[!@v��N��d^_:cU����sU�H�}��r����>T�-�J�A�JH�0n!W�-�*w�7;���D�ƪlE����p��O���W�d�����ښS��է�v|�~8���2{u	����:�㵴�^�]G! ���W����N���<33;s�D-����cj���g�v��hUG��A�� t�����Z��� �������  �˾j����:��h�^&G�Ɗ�{��5�]S�&�����n���Κ)2 ��6���  3E��I7���c2*O��7r�{��4�yW�-�K��W���Jf �j��A�  ų�0(��۲���C k��,�^|  �ؖ/��S�� �#��: \YNN*_S�k �{��j�� (4g���M�0 �p*��N�5�Pd͜Q�� �ݵ���5 P`-Rg�4[ ��%<V7�Cff33{3:��� ��-oS��  �wm5c�  ([<�� �|s�)[ ��5���& �~�J���DTP&��;���/ 0؄Vб�5;7�����i��T����"Q�yW�!-����ٹ -��j�O	 б=I�]`� P}J���� �A�i�m ��2���� ái8t @Fn��aR �Ċ�L, �0)ͷ]rh���7�q-r�� �D��2 ^+}-r�����&�.���.��p��@~�������9*`�G�H�Q	`9*����)���n,�B\���E�915n��ws2�W�  ^���������U  XQ�dX3����lbjx>s+*��&�3]񧡓����I��  ��"��-uv��v, �Z$�/�)9+~Z�k�H# �e7�ȩ�������~D �=|  �WJ��5���_�R  `��W���_?�*^lB@@p��${���Y��/\�w�z��Ӏ@�C�W���R�x����<����qh~��劀`r��~�M�����9����[�=ς�  �E�<�J�ݤ���" ��<s^�_�w�w���Ea��w��Ƚ:���,�g��ө}�ձ�]���ݟ{�tj�G�Y�8���<�w��̵�+�+���q����!I���ajj\�]E`�D~�O���쐨O�i$�%�̳����������*�懯#����,�r�vF@09�"��L�$N�-�붳@Vy6I�������!a9z@@0Ic�gal
'�[k~H��� �p��Yg��!i߬�`�GF@@p�w)s�w�#<��[��N���.������G@�����iK����G�t��bE@��kgiW����f���Y�������o"���#���u�oir�oC����(ƺ3���ɡ�Ejx+���	�Ͻ�]�J��H�{�$��'AzޞcUU:y�v&+��.=�-w��^���"1��?c�����_�%�t1��/c�A�f<*�6����!��W��6��T����K�b���W��s-T����/_zS�y�U��o��K�
�e��)��MV��Ɔ�*��iЁ��9�
��V+��cԿ-�Z�Ҿ9��`v�;@�L
	���s�N���
¤�5 �j���i�|����.T�Pj������W�sd?�n�F�Ƨ�L�e�,  8-T�P�2�À�9|�n��[��Eb�zbxZ�    w�[Bbk�L!1B�@ ����P�OŞC�b �> @'3�0aMb����  �`�P���@�',�b k�*W=`���M�9  ��G+hY_�:���������К��&t�O 7��iY_�`�m�x�Ԅ ^xu�^x5�	!% ̀�ZA�׃�B�@�s�"�. �
a�V�7^�. � �h:G�h:V��AL�x������5�Y(�q!�`+q�?.��	�8.��Pk��x��n����!F_����I��|D��`�ʨt�LT�e
  �WB��j �2���ш���2���t�ʁ  ��2�ʹ�5zm>4  x��!{��R%� ��r'���#@�;Y}�x�J�!{�\R��  ���Y�����^����y�\=JH�7�Y�izI����9��3�i�o��]N���4a���`�m:�����P��"�&�������Y�ݹ�f3��d/v��4�ƛ�F���lw�6kb�M'���;^#h��_j�  �q׊4�y*�n��؝k���YS�����Zl�To?��u��Ⱦ��SE������kii��u�Ƀ�xɃo��(N�� �D�����78@��U���εe}�}7:���5!O��r6 n+g�3z�kB��~8t��Z��s�\��%�7��Bk�YS�}�;WW��אG� �d��l�5 �Js�sm��6k*�㎄�&���� @Hót�#�t�yB ���m�9��  �/�t>��K�g�٬��g߱S�#�e  ��;d�q�<=  s���+�5z�R  P��!��  �>��ы�3W�U���  ��L7�L���Jf�f|hiƇ)�M�Bka8�m6 �/��K �|����6f��T�����6���; �*�k�* ���N�TV���C���6Z�� xq	ũ�K��^Ź��S�����"�}'����s& P*ãT p&���S���+�`(�T�a/�
 ��KŹ9 �mF�1��
�ɨ�����	 ���g���� �-G�[��rE����؞x:�'.��S�qg9�M-_ �W���1
����=�H�����fM����\�εmsV�3���]����&�7��J�͇V�8�njۜ�e���fM���f��4U�/�I��A �b�[�ԯX @�M4"��� ������f%����� ��/�I��^�>�>�Z]����b��Ղ������eAT���	�g׳dң�����c'ƪ *y�nA@@��vrl�K���	�5ۙ�*�j^�]|��~�+N������+cU ��jE@@��k���b�f���=����������B��W+q���Gs����sD ���g�
�����^z�XXf����=�����e����©�|Wm�L��6�wS>�	��Ѿ/�	���ظ�z1ς�*!��Z~�����'����r��J����Z��E� ̫G7؄!��
�oz*)ZחBs�М[7���X�i�Ԑf���DN���Tj�EE����|��dY��X��Yst��s�[ߵ;z�̧<����.*r�U+J/����Z Z���4r���uv����l���}"��OmA�s�;׾�8�4���=�Q�Ǌ]�8q<Թy�SG���z�(7Ϗ5���y�o��Yƣ�`񡣳��G�A���b��j�!Zl���c���G��2U�}�Y��4���8��Q�Giff/�A��_������U�Ҵ��J��+�H�*�B��\i� �R	�[�G�+��H_*}$��˕�t�J��w�h+�d��L�~�eѲo����U�S˾�,]��T#_0.G����TS(�
�tU��"��H�=ˏaϐ"@ZJ�@
��).��`�*�#�R)�R ��(�z*���蓌x�#^�I�"���'!"�	R�/�G�ha�90օF�ȼ)�jm�X(��Ax�*�`fzG�*�<�<ma� �B�搚܀�h�Ra��?,Z-K��ӡ�N9�I�����Ү����[t(�ݢʴ����v�Ԧ�*�H퐾�s{F�)d�:{����[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://brwp8bimc75uu"
path="res://.godot/imported/icon.webp-e94f9a68b0f625a567a797079e4d325f.ctex"
metadata={
"vram_texture": false
}
               extends Control

@onready var _server: WebSocketServer = $WebSocketServer
@onready var _log_dest = $Panel/VBoxContainer/RichTextLabel
@onready var _line_edit = $Panel/VBoxContainer/Send/LineEdit
@onready var _listen_port = $Panel/VBoxContainer/Connect/Port

func info(msg):
	print(msg)
	_log_dest.add_text(str(msg) + "\n")


# Server signals
func _on_web_socket_server_client_connected(peer_id):
	var peer: WebSocketPeer = _server.peers[peer_id]
	info("Remote client connected: %d. Protocol: %s" % [peer_id, peer.get_selected_protocol()])
	_server.send(-peer_id, "[%d] connected" % peer_id)


func _on_web_socket_server_client_disconnected(peer_id):
	var peer: WebSocketPeer = _server.peers[peer_id]
	info("Remote client disconnected: %d. Code: %d, Reason: %s" % [peer_id, peer.get_close_code(), peer.get_close_reason()])
	_server.send(-peer_id, "[%d] disconnected" % peer_id)


func _on_web_socket_server_message_received(peer_id, message):
	info("Server received data from peer %d: %s" % [peer_id, message])
	_server.send(-peer_id, "[%d] Says: %s" % [peer_id, message])


# UI signals.
func _on_send_pressed():
	if _line_edit.text == "":
		return

	info("Sending message: %s" % [_line_edit.text])
	_server.send(0, "Server says: %s" % _line_edit.text)
	_line_edit.text = ""


func _on_listen_toggled(pressed):
	if not pressed:
		_server.stop()
		info("Server stopped")
		return
	var port = int(_listen_port.value)
	var err = _server.listen(port)
	if err != OK:
		info("Error listing on port %s" % port)
		return
	info("Listing on port %s, supported protocols: %s" % [port, _server.supported_protocols])
            RSRC                    PackedScene            ��������                                            	      Panel    VBoxContainer    Connect    Listen    Send    resource_local_to_scene    resource_name 	   _bundled    script       PackedScene    res://chat.tscn �?g?
;Z   Script    res://server.gd ��������   Script #   res://websocket/WebSocketServer.gd ��������      local://PackedScene_1mb8a �         PackedScene          
         names "         Server    script    WebSocketServer    supported_protocols    Node    Panel    layout_mode    anchors_preset    VBoxContainer    Listen    Connect    Host    visible    Port    Send 	   LineEdit    RichTextLabel '   _on_web_socket_server_client_connected    client_connected *   _on_web_socket_server_client_disconnected    client_disconnected '   _on_web_socket_server_message_received    message_received    _on_listen_toggled    toggled    _on_send_pressed    pressed    	   variants                                   "      
   demo-chat                          node_count             nodes     <   �����������    ����                          ����                           ���  ����                          ���  ����                      @    ���  ����                @    ���
  ����                   conn_count             conns     #                                                                             @                       @                           node_paths                                                                   editable_instances              base_scene              version             RSRC      GST2   �   �      ����               � �        �(  RIFF�(  WEBPVP8L�(  /��,͠m۶1X��D�?��:�K*��lEmI����Q��F�$)�ݽ'�W�wu��6��h��<��c��7���?�6{��n�����E6�9��f'�Z�� l��d�t���"bTt{l�Ҷ�m��WU���z�3{�m�U��M��� n�ű۶��������PS�£ I�"IR��Zf���ӎ��+���m���x�O��~?��6S��m��������`cgl��'n)rwN��_۶-oc�����>�e�2�+)
Cgfff�b�/���Ը�b�
T�[�X�ptőT���[�l�V$I�9���3D3sU��^�@23xx�����W�m۪m�J.m���������&��W����$����!o�  �����.p�� �����S0῿��십5I���@$"�4�R�ӰMRd�Xm�Z�=�����*� N @��5P��{7W�z�ӋP�{���Xl��P�ӿ���{���^�X@�[!@*@	�C:l�
�Q�����3x·dP���SW/��b���n����_����O	t�N��ܲn@ǡ�&Rh&=�|�w�����³�V��,��Q(��_�u?�y�ۣӋ������t��q�㻯O;��Z#"�i
�a!\�uޛ����/��_�A���w�* ���������>�5�,�=-�D�@�P%� �"}�{�������� ���0��C{���һ�^̓>A���@$�"�  I��o]\,��胼 b����/� �޼�+�zS�$�>��5��P$��S�2����_�(Ai�����|�͚�D;D0;���<��n��'�Q���uޤA���	/HH SYQ����p 1PC�X��s�S7;`]��=��y}��O�κuo�C����D ��^8��D���Y�We��!���h����<n�T��2���ۣ߭�'����h�\��6W(y ���"@��ȋ��
 (Q�k��;�痣����Ϗ]��y���44o*r�����(r��|%���3��_�Y|�������1y���mH� pȌ��P��B��G��2hsz�3��3G2v�WC�sfaDd ��HZT�"�o  DFF��ka��撰ޮ�fi" � �K(B�  %�\ؾ_�=�m�=N��ǃ0	 !� 	�o�B  ��뻃��i��+?��� �22���Q(\d�����<�^�c��_���{W��T8�C
;�pB(���ǭ�|�8+��� $��I��  �.�鳦 ��4҈"S��:+}�
	 @�BI8�"�Z���l$� !9���h R	AA� ��,����@
4��y���iLc��ga�B����9�	���&h�C�DDIQr�?j�Φ���e�ӯ��AէT6÷�m:��+W�RV�N���u��1=6�ɌxVm_�
mbl>�tn7�Y��z2QL���U��	�r�Q��T��\-i��$�|�)L�CR�����3�����X�}e���I*E!��
���<w�s�3a�t%)�jU�ZN���'��ui~�a�������ihh�rcs��9�����[�7=�:,�_���1�t_q�)��K����U��~�0!m�XVK�նEW����Tt�p��������i۸nf���V��VUm)늲479������ӻ{�s�_�]����̿ ����ֆ�a�Z���f,�`�T[-�E�E(%���q퍷�'~�oᙅ�x�KO���;IS���~�.��o�/�S��׵���G�'�K�x ��������tn�B�?�?��Dfxu���*��3Y�k��V��x��_�-\�My����Sv/�R\��LLe[�xʺ=:�:�Y�o�|%���Cv�m�.N���n�j��g=�/�e楲��{n�]X�uT*;W��H*�A @�}��������_a^~�����9,��;0��X�jZh]ؔ����~h���N���W�T��K�����+��� LL�?s��3b�M�˦�Ұ0���j�Ζ���U�D^��ذ�x1��@c�3ԗ��۽���[�?�ʟ0.��wVת�P�L@P�m�FNoUE"m|X��K�|KwW>.�+����4�!��=�������Ic+�}&�x$2����_�z�}qy����Þ���������]�iKP#�T%��MSf���w���o����J�^ꯘ�؛_����q���U!�*�p��W��?��F2@�!��O�տ�Y�t���ݩ�E���t�}�l1�� &���������c�����z#����� �|�[o{�-3�K��`��.�����0 hҩՑx}߇�٬��2�+T@?�fzll�{�/����>kd��tQ�L��5w� ��C/�4�@�z0@U�j7^�u� �c��Fi<IO%ĺo��;�郞��fd� Y���xQ��b aF���oT���a��Jԝ֝�'���ʅUƋ��$0�bU�
��==p$R&-a	3��� �]T<��0A �*��E��!��c�@�R�0iQ]�L1c0Lc�Z �[D��d5fBH 0�bn����,a{c�BZ i a�c�013� P,����R o7d� Y������:_*j����6پ10Qfh�o��LFy�"�a����r���e��< ��|�[?�ׯ��]�fbi������ryY.E���vU%��E�q*`�ﱱ�C��! ��rW?���������� hb&n_���6W�K��hs(���왾���  ��w�O�W��:r��mOwˉ0 �x�(�a�i�жw��|�#���"Scߵ�W������=��������و���+�g�{��KԀNJ�|�gV7�������,=:<���($� �K��w�4L�������F��^��sic����}Ƕ__�{�}ӺՁ���ZPy���DV���\hT����́��ۭ��ݲ_��'��}�����11�_���'OW[&�a��`�h�gKV�Ĕ��L8�r|ٶ_�S�~`ݵ�ͅ�����y�A�Q6D���_	ae���ܽǂ.�k�R4��g}���{���v�6��]�2�3DBͭ�ݼ�|Z���FP���nZ���#6#(���8�1|���+����q�z"�Sm��m����9�)L4yI]������_�D�*��o��ݻ5��R�h��� ��vS.�ͤ�x<Cn�~w�;~Z00����y�c� (�/[��-�����n6, �������������w�ȞJ�II�k�g*oH,�o)ho�Nݼ��^�����Jn�n���B)E"��΃������F ���z��e��$�ph��5�o�������>�󠱐kǍ
���%�͸7�Q�0�<��J�H'��y��c@S�9zX��:���J�Z=��2 ����i~��,N����}��� ����;|�ާ��>���_��p�	����h��)S"v.@�0�y�R���O���>���ą���q_���͛6.�Ah,n���'Q���ޙ57���3+@����'�����o|���{�.t1�-��0��̯kJb#�dBZbh���w|J�=TDS2V>���M�[�������?-��(�uv�����|�ɿ�����?�X<hzh��9^��d�^+�V5p&���+������x�F[��>�ϙ���]q:z�^�Xt����u߫_���ݺsz*uYAR�(7`�muەAF���X0��+?i��r|�?MQ�� ɴ��|��l�A�i�Z�d����QwbA]b��`2[�Sqx;�܎��g�/J�qF�W�$b*�J+I��r>wZq�ê1�sv���HC�n��A���f��d������̼�0�ae��x�ն��48���LUZ�����n7/=�/�0����W���&kC����t�;|�z\c���5�DаV��t���d��#I~w���Gɘ&`�iJ�a9�|I�-�>�l
e�c�L�ڲç��c�3;B�	Ќ��dS�8����0�N� K�:- ���)�s�Ɲk�� ���ՠ(�ֶȌ��o���H�x#u�X�"Mys�|
��X��rg����o�j����uo� �����%X�X�Ow��Ұ�҅ǟ��7���D4���^_400������J�*��y���������lsȏG!Z������I�jRݞ�/�盆�*,_��8ظ�M�-y%ؤ��z�ۯ�dj�eڪ�n*@��on�TC���DX
K�m��z�m[/��Tb�ze��*a����-_�[�f,q[���&{7��YgGIk�u={�n��
����ys�Y�)э��fLpz���>x�77��
oO�VK�jJ��q�ևUC�l�+E
���|���6Y���{g�*gj�ګ??*��oH��6��h��}��_8? � ��k���x5����B+�1ZƔ�2j*�.�%�aC����V��Q�]<.ٖtqO}!�xS�M��Ž��wps�t�0R�{s�j�@�S?a}���
���G���^<����S�G������Y��aG�c���Ef�:W��S�������ׯi%i��{��`8����,1���֙��n�UGF�W�ŋJrHF�����c�da����K���q�.�2
���H�D_�������wK��J�C�� �8��<��p��sK/L_K�"x�����1��8RW�l�z��-����(�`q����6)�6 V(�)M�>��z��K﬿�� ������0"k��w%V�2j�B+g�ګm�1s��h �G2��٥�_��������k�ov�]Ƅ�@�&o:�xp�z�[�%�����+G� @C�,���LL��a3�1z3A��7Z+�[x�Ys@'{��v��L�A!��t��x½\vy�31f3uݥ�.w��E8�;�G�|P�(���z����e��(��5)=�� �x�{��	 (����/����31��[�z�f#c�A���e�7{��:�C�l˫ 2����z� �-ЬYu�C��x�#V��!��w5\�Q��u�����a��`L�XEO�M֭�*M��YO+�[}��.���9� :���5�q?����Dݵ�؈�J�J7Y  ���v- %�����_���dɤ� �ʰ�=��e���_�=����P%2J� }q{x��Aࡴ�1>O/�G J�d#�Ҝ�;�<R(�EoRӪ\������	�R�CW.[�%o��Q�YZ�58���/��h�I��a5�i7�o�Ts2�L�����G� �8��v݇�{����:oO9�֕�ͱLP  E�6��u���S
>^�{Ե��]��$@@�V)�6{w�}  �@Wɤypv#���s]�:�b��G]c�}@�Ϝ�(�I	��Sݎ�h  ����6�y��)Z �ӊf'���1K��"` ��O�u�x�wN����iG�  `�a�hG[����^�2��/�6��O^Y{:4%h�$����I�b�k�Y�lp�B��F#Q�>9��<I:�Ѭ�YF��)��,�3�Q�eX/f��'�"���5�$���D/�(e|  ����h�Vޒ�#�1��0�+gY�^񞵊Y����zfT���ԕ��́�!ͳ�F[l�y��r�������<���O���n������z����8��k:}r�<�K�'�����n&,|e�>�g^��v�t˻������_��/��?����W��.��=�ۿ�U?�gf���tDgGt,���������E2�v�}�w�W�6��6�]�`��ڲ���I4-|�����?�������ߗo���]|�=��_�����g��K��:��w�)}_�u>�i��y_����g5�.>a1}��z��[������w�.���U8i�ӟ>��������_���?V��O4�����蟵�*<���/��W����Ǒ;*u6u�#-e�����>�O��k�+�,��G֦p�K�e?����iZ:*8��0�ٲ{�i�"}��+��;?���r��y�������Q��߲V���_��˿���~�w��W��g��?��Au��w�W�)��k���?u�����XV�7��k����rOh �b�S۪����/غ�K:���������w<�h��s�#s�3{���C�㫲�z�x��@��Īz]��LY����;�/.n#0��*��]� �ՙ��a�0��y[��DY�b���_:���q�ܩ�}���Y���O�(�@w�"�y�1'3�­��⬩�ھ/��8 y�-�"�J��%R�����Nk����j1;m��)Q J�N�H}\����b,Q���(`:�B�ۮ����N�E�R� C���	JU1�>4���<�_ ����5�G"ۯ{�f�e`���<�H�cD�o �a�2Ʌ
	��^�*��ޤ��?@�TXE��C# �l��BI0~�6�DS�g� ����?Sk� �?o����� X�g� ��IT	IOXM��@[l�F�	�3@�'�8Xe��f�p	4 XI�E+�0%�b$��ZE�J�6��'#��i$�:�qb�U�x ����ٕ�1��4c�e�I��`4\*�  ���i!iC<���9-����g5��bR6(��嘀�G�Tn�B� D "�=��@��B�M�������X��b5��=ĨL ���K�^��᪚_xc�q� c  !�J@'~Ya��u�j�ːA}J�RM2���VҌ�D�R	 QB�8�@ 	B��ڮ<�R�Q�l"�Yd!� "	"B�D?���������n;�]֬�胩�:# -M�`LWm�"V�iY�i�J �,x���ѩA�(`L 'R�p3#c�V�d1�(�a�Znv�&�On6kt��433RT\E^&+�%����!�$	�4%-���MQ�D6Q0YF#s��@3}�V�[q�Q&���&h�T���(�D��2M�����\@N�2	�i���zcHWf Z���'�f��D&��5n� �Ӷ���ޅH�]� @$�n�L� ��v�z�r9^���s�j�)O�%�D�~��1 �&B	���_ii�ͽX 0cUo��Js !��#���n�F�V���Z�i"��i,�y�z��   �DR�qb �����b 8��MQbZ֨�m�e��h�f	��f]��P��<n1zbu�-�B��  �MOW��p7� c������1�  �;N"����G dZ������������/  |Q{Z�bK,'� fe�7��4u1�*�4�:_�Cta��&��L�ބ�*i���0'�
���1־Iqa�Xo�` ����1,��� ���zS���B(ѥ�$-E����)�2�D�t%#k H@So��$�ڄW�k�Ց�� 
x��Qf5f��	 T� CU���� ��~�/~maq<\N �V���$��Tp��p9�VҐ�DȢʴ\� ԮI}D�� ��X��Y<N�:bic��K%��0%DoY� ���~�TmX��`�| ���s��>�ww�U�[8r����������F�1@��I���$��
�`�G��jU��ӻ_w�����]Vj�b�h8V����~q��D��h�_[�4}Ȑ��.  �VJ��D��ް� ���&L[���8�����7NN%���gF���a��j8�8=��������?��1w2{l��)����0c�F��#�0�1F��5�i���G�Ӫ�Pܓ@hHO1m�d�2m��4�6i� �[�����3b����mݩ,����F����8��z�-,x��'�~����^�)g���ٖu �Ye�cf#�Q�Y�;H;�D?B�갬E�|Sy�JB�U�!hZ��WA��W>�X��P�r��=�0������ȄLA�?n��M�h�*� j�:�c��0
AAHh�&��r���6�'=e���B�I�&�+H�(��bO�1�����Y�aq�!Ewn߭�vh�M���	FG�<�/�˓i�tgM|z��ha� �>�����E�x���v/i������ǆ[�J|r�w�{��2M���=x��N�X�R���h"�Φ2��������]�h��m�n���O�ɝ&BY6�ӥ6\V�b.n�}}7D47�ھW]��$9E\� �Mg�
m��3��8��m�L��m�y�K2F~j�Y�c���9y�#ˊc/v7���Dm����[�WY�a�Ѫ���D�� hI�X�BV�F��� $�m��=9_j�dY�dg�y�L ��i�^`D�8�T�W�<3�������y�[�$E#���(�S���;^����F��I<����A�P�U[��?���"E�f�`����4Zf�U
 `t�i���'����qR��非���r���1���W:^af1��FLX��jI0Z)�mO�Ɗ�&��+���tg�ׅ]�%bD���,w��eg�{���jD
�U����؈�1�y�t�W�(�Ҥ�ޔ��=�ѣ��r��=���/,Y�i��ǫ��{��`�ȅ���he�ַ	 DD�7>o}���E�<�7t�4EE��z\T@�ws���j��Y����b*�a��pT]�,�ϯ�	sQ��.N*��[M�dÂ�e�����`�uZ���֩�թ5+m��f*[�kC!�ȣF b,H��ڢ����\��H�Δ!�j��h�������Mb��06�� ��z��:��͝V��p8�p�����ی�p �'�DC��hDc��<��q����p�e9/G�Y����� �`�����y�����ί� F=�r�M��x%�����	�DR��saă�!BD�ГY	D`�  В�d�:(��1bL6�� Vg�Y���$�xfV69�̰�RQ�{gG'�wztztRU몕A�X$��XO�c�pa�b�g1f4�gqx�?S�ij��:�ԅ�D3�22�:��&"�Y0�xnfʴ���*IMע�)ov~����~���{�g<FA�1כ[Lc�1���]Ą�uO�6d��t��v�߅�&� <�C}$�%�ּ�뎮:�����y�d��
0fafg.r�d�O���Za�[�#+�7�@�f���M��T{My��E����w���6w���+���klʮ+��/��vVr�}�ՙk�ƌăa��  ���C�X���
�C�"������D���ݵwES���N�P�Psa�y�������M�
�L��f���,��P���#V}wQ��#l�ǴK����N�P�"��M��$�j�XƃJ�Hf�x4�c�:4D�  �$-mZJ��JT��FӳL����_�%�C�"b��'�88T��@E8G�l�*�P�����.�� J�B�F��Fd�Yk��>Wz�PY�!���a*�Ӱ��S 8�l�H"f��7"�8�ã�7 ���-�H"k��Mv�⋧Y^]���ipE��H�`/:�0 fW�Ծ}�y���������z��kB��� ��m��Z�f �����\��"<�>W�D \QN�E� СVD������˛g�vY�g�����!�D ��#��iъ~
 �b͹�W�j% v����4}J Y��Ic���  N2�v~f9lg���Ͼ�%w�!J @E��� Ys ����
S 0��>���c� @m�w�M���ն������ ��M����Y������D�� �}w{h���u3�T# ��/\�!M[�g����eR���t�r�am��'�T��.`�����V�7(҄ Ad�/ ����
f���jh�  �
�b�y9�~��o��ǋ���d��W�k�#��*\�F�ԐJɟZ��a�+��� �ќ�8�w����*�X~>  g]S�;}��)a��@(�d�0���1��,^��qq�vC���~�ᬆ�ӭ[�Yn{Z�A�A�´'��]�Ϫ��O��_��r l�7o/��a�/�c�t��'���(�Z3"�(@���U��RD�������ڭ�T����v��0(�<%@r���~����snYף��@�I(�Qdm��Y�~:֦�cv6��ծ:gՠ�r�h�}9��\3��������A��~�ɴPj�D����`�B	�K+L��!�}���]�����޼��6+w`�����h�v  ���9���� ���@&�����m���0�9/�f�4[�@$� ���E�٫m���~X�n��ӛ�q}:��^�6��           [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://ci4k0fbay0b8x"
path="res://.godot/imported/WebSocket Chat Demo.apple-touch-icon.png-709f2ca028ff86ef92976b999caf8b28.ctex"
metadata={
"vram_texture": false
}
                GST2   �   �      ����               � �        �  RIFF�  WEBPVP8L�  /�����^""""J�������WY���՝�����g���0�efffffffjzK����+�eɶ�H������ᏩQi�IY�P��	I�$G�����NeuW�9i���m���j0��.�Q6̵(5��e��P��6�$��I��>&�o����ڴ��xvw�mv���w��A'8�w��
��!5�ϓ_���%��$���ՙ�$K��-/E:ql##A���m���&	6���Ⱛ��$7�I�]Wx���7��骈�e)�bա��-�L�ܞ��Aj�J-R�W�Z�vH���=��Unu(r�Z7�tO鞶Q(�t��R2���J��(���Z6�� %3!5Z6ײ��7�*��H�P�ZuU�p�tB��J�$��-�u�X��c]h�P��O�]&��t�P屔G�J��l�cUF�x�%*�/��]	�J=���1�i��*+�V���ԃ�j�UU>s%{f���a��ժ򙍚?��OH�ˍU�R�.5���)����h;��A7��@v�Qm��*KG[!@v��N��d^_:cU����sU�H�}��r����>T�-�J�A�JH�0n!W�-�*w�7;���D�ƪlE����p��O���W�d�����ښS��է�v|�~8���2{u	����:�㵴�^�]G! ���W����N���<33;s�D-����cj���g�v��hUG��A�� t�����Z��� �������  �˾j����:��h�^&G�Ɗ�{��5�]S�&�����n���Κ)2 ��6���  3E��I7���c2*O��7r�{��4�yW�-�K��W���Jf �j��A�  ų�0(��۲���C k��,�^|  �ؖ/��S�� �#��: \YNN*_S�k �{��j�� (4g���M�0 �p*��N�5�Pd͜Q�� �ݵ���5 P`-Rg�4[ ��%<V7�Cff33{3:��� ��-oS��  �wm5c�  ([<�� �|s�)[ ��5���& �~�J���DTP&��;���/ 0؄Vб�5;7�����i��T����"Q�yW�!-����ٹ -��j�O	 б=I�]`� P}J���� �A�i�m ��2���� ái8t @Fn��aR �Ċ�L, �0)ͷ]rh���7�q-r�� �D��2 ^+}-r�����&�.���.��p��@~�������9*`�G�H�Q	`9*����)���n,�B\���E�915n��ws2�W�  ^���������U  XQ�dX3����lbjx>s+*��&�3]񧡓����I��  ��"��-uv��v, �Z$�/�)9+~Z�k�H# �e7�ȩ�������~D �=|  �WJ��5���_�R  `��W���_?�*^lB@@p��${���Y��/\�w�z��Ӏ@�C�W���R�x����<����qh~��劀`r��~�M�����9����[�=ς�  �E�<�J�ݤ���" ��<s^�_�w�w���Ea��w��Ƚ:���,�g��ө}�ձ�]���ݟ{�tj�G�Y�8���<�w��̵�+�+���q����!I���ajj\�]E`�D~�O���쐨O�i$�%�̳����������*�懯#����,�r�vF@09�"��L�$N�-�붳@Vy6I�������!a9z@@0Ic�gal
'�[k~H��� �p��Yg��!i߬�`�GF@@p�w)s�w�#<��[��N���.������G@�����iK����G�t��bE@��kgiW����f���Y�������o"���#���u�oir�oC����(ƺ3���ɡ�Ejx+���	�Ͻ�]�J��H�{�$��'AzޞcUU:y�v&+��.=�-w��^���"1��?c�����_�%�t1��/c�A�f<*�6����!��W��6��T����K�b���W��s-T����/_zS�y�U��o��K�
�e��)��MV��Ɔ�*��iЁ��9�
��V+��cԿ-�Z�Ҿ9��`v�;@�L
	���s�N���
¤�5 �j���i�|����.T�Pj������W�sd?�n�F�Ƨ�L�e�,  8-T�P�2�À�9|�n��[��Eb�zbxZ�    w�[Bbk�L!1B�@ ����P�OŞC�b �> @'3�0aMb����  �`�P���@�',�b k�*W=`���M�9  ��G+hY_�:���������К��&t�O 7��iY_�`�m�x�Ԅ ^xu�^x5�	!% ̀�ZA�׃�B�@�s�"�. �
a�V�7^�. � �h:G�h:V��AL�x������5�Y(�q!�`+q�?.��	�8.��Pk��x��n����!F_����I��|D��`�ʨt�LT�e
  �WB��j �2���ш���2���t�ʁ  ��2�ʹ�5zm>4  x��!{��R%� ��r'���#@�;Y}�x�J�!{�\R��  ���Y�����^����y�\=JH�7�Y�izI����9��3�i�o��]N���4a���`�m:�����P��"�&�������Y�ݹ�f3��d/v��4�ƛ�F���lw�6kb�M'���;^#h��_j�  �q׊4�y*�n��؝k���YS�����Zl�To?��u��Ⱦ��SE������kii��u�Ƀ�xɃo��(N�� �D�����78@��U���εe}�}7:���5!O��r6 n+g�3z�kB��~8t��Z��s�\��%�7��Bk�YS�}�;WW��אG� �d��l�5 �Js�sm��6k*�㎄�&���� @Hót�#�t�yB ���m�9��  �/�t>��K�g�٬��g߱S�#�e  ��;d�q�<=  s���+�5z�R  P��!��  �>��ы�3W�U���  ��L7�L���Jf�f|hiƇ)�M�Bka8�m6 �/��K �|����6f��T�����6���; �*�k�* ���N�TV���C���6Z�� xq	ũ�K��^Ź��S�����"�}'����s& P*ãT p&���S���+�`(�T�a/�
 ��KŹ9 �mF�1��
�ɨ�����	 ���g���� �-G�[��rE����؞x:�'.��S�qg9�M-_ �W���1
����=�H�����fM����\�εmsV�3���]����&�7��J�͇V�8�njۜ�e���fM���f��4U�/�I��A �b�[�ԯX @�M4"��� ������f%����� ��/�I��^�>�>�Z]����b��Ղ������eAT���	�g׳dң�����c'ƪ *y�nA@@��vrl�K���	�5ۙ�*�j^�]|��~�+N������+cU ��jE@@��k���b�f���=����������B��W+q���Gs����sD ���g�
�����^z�XXf����=�����e����©�|Wm�L��6�wS>�	��Ѿ/�	���ظ�z1ς�*!��Z~�����'����r��J����Z��E� ̫G7؄!��
�oz*)ZחBs�М[7���X�i�Ԑf���DN���Tj�EE����|��dY��X��Yst��s�[ߵ;z�̧<����.*r�U+J/����Z Z���4r���uv����l���}"��OmA�s�;׾�8�4���=�Q�Ǌ]�8q<Թy�SG���z�(7Ϗ5���y�o��Yƣ�`񡣳��G�A���b��j�!Zl���c���G��2U�}�Y��4���8��Q�Giff/�A��_������U�Ҵ��J��+�H�*�B��\i� �R	�[�G�+��H_*}$��˕�t�J��w�h+�d��L�~�eѲo����U�S˾�,]��T#_0.G����TS(�
�tU��"��H�=ˏaϐ"@ZJ�@
��).��`�*�#�R)�R ��(�z*���蓌x�#^�I�"���'!"�	R�/�G�ha�90օF�ȼ)�jm�X(��Ax�*�`fzG�*�<�<ma� �B�搚܀�h�Ra��?,Z-K��ӡ�N9�I�����Ү����[t(�ݢʴ����v�Ԧ�*�H퐾�s{F�)d�:{����[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://bals38083yrh3"
path="res://.godot/imported/WebSocket Chat Demo.icon.png-158243a759e0120c7795fe5dfa1c6669.ctex"
metadata={
"vram_texture": false
}
            GST2      X     ����                X       �,  RIFF�,  WEBPVP8L�,  /Õ�mۆq�����1�Ve���G�N^6۶�'�����L �	���������'�G�n$�V����p����̿���H�9��L߃�E۶c��ۘhd�1�Nc��6���I܁���[�(�#�m�9��'�mۦL���f�����~�=��!i�f��&�"�	Y���,�A����z����I�mmN����#%)Ȩ��b��P
��l"��m'���U�,���FQ�S�m�$�pD��жm�m۶m#�0�F�m�6����$I�3���s�������oI�,I�l���Cn����Bm&�*&sӹEP���|[=Ij[�m۝m��m���l۶m��g{gK�jm���$�vۦ�W=n�  q��I$Ij�	�J�x����U��޽�� I�i[up�m۶m۶m۶m۶m�ټ�47�$)Ι�j�E�|�C?����/�����/�����/�����/�����/�����/�����/�����̸k*�u����j_R�.�ΗԳ�K+�%�=�A�V0#��������3��[ނs$�r�H�9xޱ�	T�:T��iiW��V�`������h@`��w�L�"\�����@|�
a2�T� ��8b����~�z��'`	$� KśϾ�OS��	���;$�^�L����α��b�R鷺�EI%��9  �7� ,0 @Nk�p�Uu��R�����Ω��5p7�T�'`/p����N�گ�
�F%V�9;!�9�)�9��D�h�zo���N`/<T�����֡cv��t�EIL���t  �qw�AX�q �a�VKq���JS��ֱ؁�0F�A�
�L��2�ѾK�I%�}\ �	�*�	1���i.'���e.�c�W��^�?�Hg���Tm�%�o�
oO-  x"6�& `��R^���WU��N��" �?���kG�-$#���B��#���ˋ�銀�z֊�˧(J�'��c  ��� vNmŅZX���OV�5X R�B%an	8b!		e���6�j��k0C�k�*-|�Z  ��I� \���v  ��Qi�+PG�F������E%����o&Ӎ��z���k��;	Uq�E>Yt�����D��z��Q����tɖA�kӥ���|���1:�
v�T��u/Z�����t)�e����[K㡯{1<�;[��xK���f�%���L�"�i�����S'��󔀛�D|<�� ��u�={�����L-ob{��be�s�V�]���"m!��*��,:ifc$T����u@8 	!B}� ���u�J�_  ��!B!�-� _�Y ��	��@�����NV]�̀����I��,|����`)0��p+$cAO�e5�sl������j�l0 vB�X��[a��,�r��ς���Z�,| % ȹ���?;9���N�29@%x�.
k�(B��Y��_  `fB{4��V�_?ZQ��@Z�_?�	,��� � ��2�gH8C9��@���;[�L�kY�W�
*B@� 8f=:;]*LQ��D
��T�f=�` T����t���ʕ�￀�p�f�m@��*.>��OU�rk1e�����5{�w��V!���I[����X3�Ip�~�����rE6�nq�ft��b��f_���J�����XY�+��JI�vo9��x3�x�d�R]�l�\�N��˂��d�'jj<����ne������8��$����p'��X�v����K���~ � �q�V������u/�&PQR�m����=��_�EQ�3���#����K���r  ��J	��qe��@5՗�/# l:�N�r0u���>��ׁd��ie2� ���G'& �`5���s����'����[%9���ۓ�Хމ�\15�ƀ�9C#A#8%��=%�Z%y��Bmy�#�$4�)dA�+��S��N}��Y�%�Q�a�W��?��$�3x $��6��pE<Z�Dq��8���p��$H�< �֡�h�cާ���u�  �"Hj$����E%�@z�@w+$�	��cQ��
1�)��������R9T��v�-  xG�1�?����PO�}Eq�i�p�iJ@Q�=@�ݹ:t�o��{�d`5�����/W^�m��g���B~ h�  ����l  נ�6rߙ�����^�?r���   ���⤖��  �!��#�3\?��/  �ݝRG��\�9;6���}P6������K>��V̒=l��n)��p	 ����0n䯂���}   ���S*	 ��t%ͤ+@�����T�~��s����oL)�J� 0>��W�-  �*N�%x=�8ikfV^���3�,�=�,}�<Z��T�+'��\�;x�Y���=���`}�y�>0����/'ـ�!z9�pQ��v/ֶ�Ǜ����㗬��9r���}��D���ל���	{�y����0&�Q����W��y ����l��.�LVZ��C���*W��v����r���cGk�
^�Ja%k��S���D"j���2���RW/������ض1 ����
.bVW&�gr��U\�+���!���m ;+۞�&�6]�4R�/��Y�L�Ά`"�sl,Y/��x��|&Dv�_
Q*� V�NWYu�%��-�&D�(&��"  Wc��ZS���(�x� ,�!����!�L�AM�E�]}X�!��wB�o��-  �-���16���i���ю�z��� ���B��oB�0������v]���ȓ�����3�� +S�χ�=Q_�����˨�d��|)D>��k ��uȣ���Y[9̂�����! ^�!��r���j0Y+i��΍e(�ț� ���x��
��{��<6 R���پ�b��Y
C����+���������;���a ���,�o��bC�{�?���1 �(��¤ �V�������;�=��I��� ���EI���Z��)D����t=S ��] X��9K�= �.~�K[��Ŋ��,2��� p}>w<n�g h�
�t���R�u�G�1k���!��x���������� �L���|>D�0�Ǣ(Qc�� ����= �ۊ�Z0�^��c �
|�����L�%�d��q���(�WB� ��(	���� �J��8D�0�~$�Dsy�Ѿ!������j�^ ��mOa�8.�qce��s|%Dq~,X�u�������=T	���Q�M�ȣm�Y�%Y+�[�0|"DΞ�j�u�L6�(Qe��qw�V�э���ǂ���!j�K � �:�wQ�dÛ������R�
��C���X�u�`����\"j讀Dq21� �F>B[��[������]@K-���C�e�q�tWP�:W�۞X�z��,��t�p���P��Se����T���{dG��
KA���w�t3t��[ܘ�4^>�5ŉ�^�n�Eq�U��Ӎ��α�v�O6C�
�F%�+8eů��M����hk��w�欹񔈓����C��y訫���J�Is�����Po|��{�Ѿ)+~�W��N,�ů��޽���O��J�_�w��N8����x�?�=X��t�R�BM�8���VSyI5=ݫ�	-�� �ֶ��oV�����G������3��D��aEI��ZI5�݋����t��b��j��G����U���΃�C�������ق�в����b���}s����xkn��`5�����>��M�Ev�-�͇\��|�=� '�<ތ�Ǜ���<O�LM�n.f>Z�,~��>��㷾�����x8���<x�����h}��#g�ж��������d�1xwp�yJO�v�	TV����گ�.�=��N����oK_={?-����@/�~�,��m ��9r.�6K_=�7#�SS����Ao�"�,TW+I��gt���F�;S���QW/�|�$�q#��W�Ƞ(�)H�W�}u�Ry�#���᎞�ͦ�˜QQ�R_��J}�O���w�����F[zjl�dn�`$� =�+cy��x3������U�d�d����v��,&FA&'kF�Y22�1z�W!�����1H�Y0&Ӎ W&^�O�NW�����U����-�|��|&HW������"�q����� ��#�R�$����?�~���� �z'F��I���w�'&����se���l�̂L�����-�P���s��fH�`�M��#H[�`,,s]��T����*Jqã��ł�� )-|yč��G�^J5]���e�hk�l;4�O��� ���[�������.��������������xm�p�w�չ�Y��(s�a�9[0Z�f&^��&�ks�w�s�_F^���2΂d��RU� �s��O0_\읅�,���2t�f�~�'t�p{$`6���WĽU.D"j�=�d��}��}���S["NB�_MxQCA[����\	�6}7Y����K���K6���{���Z۔s�2 �L�b�3��T��ݹ����&'ks����ܓ�ЛϾ�}f��,�Dq&������s��ϼ��{������&'k�����Qw窭�_i�+x�6ڥ��f�{j)���ퟎƍ3ou�R�Y����徙�k����X�Z
m.Y+=Z��m3�L47�j�3o�=�!J
5s���(��A ��t)���N�]68�u< Ƞ��_�im>d ��z(���(��⤶�� �&�ۥ� ��  Vc�8�'��qo9 �t��i�ρdn��Of���O�RQP���h'������P֡���n ���č����k�K@�>����pH>z)-|��B��j���!j:�+������˧��t�������1����.`v�M�k�q#�$���N:�����-M5a10y����(�T��� X5 \�:� ?+�7#�?�*Y+-,s� ~�|\)뀀ap �drn�g��RN�X�er ��@ĕ���;��z��8ɱ�����	�- �
�bKc����kt�U]�䎚���hgu���|�_J{ �`p��o�p�T�U��p���/���Hϑ�H�$X ܬm3���ŉ�U'��뻩t��G9�}�)O������p�΃g���JO���\9�׫�����ڳ�!k����/��9R���^�%��C����T���;ji<�>�KY����;�J��ƶm .P��pT��
@HA��r��98V���b�v���YwaZ>�$oւ?-փ��ʹ|0�.��3���b駁�c��;?8E;���V�B�؀����|%\\s��%����e{o��Z�i�������^���s�Jx������B jh�\ �h�<��V��sh@:���.�ІYl��˂�`3hE.,P�2^����J��+�����p��
�ЊJd��x�*�@�7R��� �"�G="!�� �p����u�o��wV�m�g���~F��?����/�����}~����sо7� ���\,,k�J�T�6������Z�y�rBZ[D�>v�HQ�R��mq�������DD�-6+�V`���J�E�����\� 9!ߑ�`��6���ml�~ZM�Z�ȎV���g���������3?*u3���ctW����YQa�Cb�P�,B5�p0�m�cͺEt�{,��>s9f�^��`OG��]����2�Fk�9_�G�vd��	��)��=�1^Ų�Wl3{�����1��H)�e������9�هZ�]}�b���)b�C��es}�cVi~x���e
Z�)܃��39������C�(�+R����!�j����F�n���<?�p��l�8a�4xOb��������c�8&�UA�|	/l�8�8���3t�6�͏���v���� ����סy�wU��`� =��|M�Y?�'�A��&�@*�c~!�/{��),�>�=xr"	�qlF:��L&���=<5t�h.�#ᣭ���O�z�!�&`A�F�yK=�c<\GZ�� 4HG�0i�F녠uB"���<��c�Jeۈ�3!����O��q萞PiZ&�$M[���(G��e���ؤ���ã��O���5����'�gH~�����=��g�F|8�+�X�4�u���G�2����'��.��5[�OlB��$f4���`��mS�L�,y�t&V�#P�3{ ��763�7N���"��P��I�X��BgV�n�a:$:�FZ���'�7����f������z!�����KA�G��D#������ˑ`ڶs���&� ݱ��4�j��n�� ݷ�~s��F�pD�LE�q+wX;t,�i�y��Y��A�۩`p�m#�x�kS�c��@bVL��w?��C�.|n{.gBP�Tr��v1�T�;"��v����XSS��(4�Ύ�-T�� (C�*>�-
�8��&�;��f;�[Փ���`,�Y�#{�lQ�!��Q��ّ�t9����b��5�#%<0)-%	��yhKx2+���V��Z� �j�˱RQF_�8M���{N]���8�m��ps���L���'��y�Ҍ}��$A`��i��O�r1p0�%��茮�:;�e���K A��qObQI,F�؟�o��A�\�V�����p�g"F���zy�0���9"� �8X�o�v����ߕڄ��E �5�3�J�ص�Ou�SbVis�I���ص�Z���ڒ�X��r�(��w��l��r"�`]�\�B���Ija:�O\���/�*]�þR������|���ʑ@�����W�8f�lA���Xl��촻�K<�dq1+x�*U�;�'�Vnl`"_L�3�B����u�����M���'�!-�<;S�F�܊�bSgq� ���Xt�肦�a��RZ�Y_ި��ZRSGA��-:8����yw_}XW�Z���-k�g.U��|�7P�
&���$˳��+��~?7�k�bQ���g������~�Z�e����H�-p�7S�� 
�w"XK�`K%?�`Tr|p���"��\�a�?�٧ ��'u�cv�&��<LM�Ud��T���Ak��������'+7��XR`��[\�-0���e�AiW]�Dk���$u���0[?�-���L����X�ĚSK-�.%�9=j�3t^���(c�yM-��/�ao����\%�?�б �~���b][
tٵ�<qF�)�
�J�'QZY�����*pB�I4�޸�,������.Т�1���/
t�1-1������E�*��Cl/Ю©f�<,0�S�bf�^���[8Z$��@���kw�M<?�[`��)3)1� �U����:��/pR��XV`XE,/0���d���1>ѫ��i�z��*o�}&R{���$f�JV=5͉Ύ��Rl�/�N4.�U~Cm�N~��HPRS�?G��g�-���qvT{�G _�[ua�;���kco�9�Kw����n����E{d�j��C���,q����Y���cwY<$#�ؤ�m+�LL-�z� �y<{/7���[��X�?�-6(cO ?�XZ�M�������sb�[
�.����j|;d�!0lCIqZ�z�&��~�|7�A���A~��á@�� 417��}t ��,� X�6��lS)6v�G
��I:�).~��8R���#'��߶;9�'���U�$1nC�L��찦3�+b黙u�NJ�����8���X�?5�0��^��[B/+�0�Ur(��J��+Xr�H�����HZm&�#�p	�Y ����*���hM]��m���b�ݢ����G����s��z-�x��������� �J�"���Ћ�g�Ҝ �Aа��?��?6��c�Zx�$�t��{s
-R�E�24�?�{�l�-��1�3S�EJ��v6X]L�B^ ��]N��R�yN��62�����'R�p-�����n2�d�?Th|�h��3X������Rc8&��_,��;T�8�� �hΗv�(7I;�3Obn;��O�!����Lߍ*�E~wU,���n�MN1���Z��Y̖��tY;5�^�<Z�Ǩ�T#�bt�xfA�n�cq����"9GD*�^JL��HJ���4���V�-�܉��4*��u]�[
���,"ҏ�i!�r~L��_�����8 ]j�?x���<k+%w��Bk��=�u�ڤ��>%2Bۃ�Y�n<jBo������Κ�0M~�t>�#b/jZ�}���B��Q��#���6R$v�����k�R$c/:�~���(V�7;)��ߊ[̣0?F��;.�*ݪd������{A`w>~�i=D�c��������Y2�X�q~�r2��8@v=f�?��X��S�"X�j?��@$?�����x�(�k���c7��\�����>A�=fpM?9d?�׻{���)f�.⪝���3�������f,N;"��,N���X��*�"V���"��C��?���(2=���A��1�Ul���h�8Ao(5X�B�X�>S�j��s�!
l����GgGp��>�v;c���V�N1���-��K�S�=6PiN�fNq������,
�3SWx�ei����f'�*�r�rʹ̙�e�7���b�o���>_i��M�_��V�p�r�9��X�$�����B���t5�4#�B(E���3�������`����I�M�e��b6_����{~�f/��@��B��Y����E�4��޲�d�O�$���M�����ݖv�P����TR�oj~��+}��#���"�]1Υ_���nR���œ����^pQ2�7첾b��3�ba�\��uu2�~O�G�����5�^>v������m��?���mC;$eT��C񎋋��V��8�:��
���ʱlt��~e]�cC7dl���.�i����\w����/..F�Q5���œ��`�o���E����E�͛�ٽ-�o�z�"n��/��[�����ͳI���S��Dڢ��V�6��!��esq��AC���ڻ���OMk�y��{7`c0�ٺ���5C5�yiw��`ps�OC��f�X�5oQ�\_*m�f�)稹"���a2$O;�]C�A�;V.���c��iޢ�R5�X��t%�s����ȸ�; 5�����)��X|?����9&��wĽjdn�{��7��/����q]3Ɲ�}�[��yF~�Q0����x��U�� ���˘?����a�;���/yޫ�����6.��C}���&L��9�_�ս�w�o���W�^�;�^u�xoݖ��Q8����4��kW��'����:9>����Xp5H��ONtL��=��_�&�0��H"Q��|H���4!���]�'�!޹Eܢ���}=soϢ~	K�$���`"!]j�+{'e�M��D]��=�>c��xS��Y����X��7�7+�Me̯/���u�Q����i���Eg�9�g�RU��#'��ޑW\r�aS�/3�"/v
IgX���}ٻ���ʏr�r���_��<�6�Gʋ&���z%�Pl^d����㑭v�ʎو�w�[���Q��k�K�����IWˈ��`/�Y�X��9J"��_��V{��je�i��6�<�ZS��� �t���W�Bg��@5���..��X�eʡ��*�HRgkD^>�y裝"�9�+wQ4ABR������^�k3�>2�����x�C�l���f:��#gщ�s� ��ߜ��ȁ���+���A��˾�g�1K9Cܹ��:���T"!I������Hs�;���ue��9@#ChE5&!��'�2�����w*a/Q��I	�E������I�w�����?��v })B��GQ�n�h"]0��]Z֑���.}�&~x2��
eĞsF�n�+�b�e�i����0Ix�y��Aѕ���
[1�B�R$$����:�4E疳��#�4���y���ӈ�6o1O�V'��7]�H�.)/)�OwW./�g�l��£���"$d���}[���t���U~�MQԲ�$��~��c��S�M�a���ш=��diH��(N�+U�D����f"V�"�����.ƈ�#Ͼ�eH:�x��d!k 6�J�f9�GW�4����Kp��T��3��~��G�؀��,�zZ��澰؋7����v#� &�r+O�@Ud7͐�$�\�D�O��W_�Ew�ͻ�7��oD����y��,��Ƣ�cƙd	���U�u�:�#�h6]�R
�U~	V�՟R�V������/�:r�F¬�k?|Ī�r\�<.�^9����?��]Aʻ�iT;vg�PpyM���1��},�dY\e8��I��2�wjM��S/�p�1�\^�6$4�F��(:�\nۢ�2�}�Pm�X�'.����U�3��bq�nXK�i_BD�_H}�r;Y^�t�<���o��#gw��2q_�|�^�<��E�h���O�����R�-Ɖ���S�	!��z�1�+iH�1G���+<����~�;|�F�{�}v�;s�j�Q;�٩�;&f�}�������tL ���#��Ъ>;��z���?U˽�~������e��{K%��/:F�/<�n�2k�8�x��S-�5�`��ԗ�H�{���R�y�S�(w��ѥe
�	0���w�޻�U1��7V-Q�̶ꪸ�g�X��3V&�T[+)b����2���(���B��,��z����9���B`��!��o�ע(�W�RZ���m��%/V�&��|g��f��*[_��nn��M�M`�%��)��Z�K$�����F�� ��$r^�k�K,	u;w������X���;�L�eoI�6��y%����~����)���0"�zc�BH�<�kW�E\.�b��R>mٺ��<����͑Թ���a=2X���=/��_;	Ρ�e&o.����]��2!�嫈�"I������j�höR��͒\L�0�e������,)ýf�; ��E��0��<%�Q�Aø�x8�� �]eQL�;|���꼬z�W2
�H�z�_��
/K`J�O�O�Y�~j���>����d�v��%�ެ7�4{%��٥7Z��>����|��5^�\ױ���:��Z^;��U��s�)��#�|�.̡���R2��j����şBб���*cMvD�W^{�������m�D��0�,������#���?O����
����?z�{ȓ'�|����/�����/�����/�����/�����/�����/�����/�����/|�           [remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://c4o338tycagta"
path="res://.godot/imported/WebSocket Chat Demo.png-9a74e8cea2168875a4039ff9ffae7069.ctex"
metadata={
"vram_texture": false
}
 [remap]

path="res://.godot/exported/133200997/export-59f5893cf12fc754877ad92fe5b9f384-chat.scn"
               [remap]

path="res://.godot/exported/133200997/export-28d74bcfaeb4b0ca75c8bfcbf615d89f-client.scn"
             [remap]

path="res://.godot/exported/133200997/export-753b2295faba52a01a8aa2a973e9096c-combo.scn"
              [remap]

path="res://.godot/exported/133200997/export-c89a2950482f3a432bab03a0591e8d28-server.scn"
             list=Array[Dictionary]([{
"base": &"Node",
"class": &"WebSocketClient",
"icon": "",
"language": &"GDScript",
"path": "res://websocket/WebSocketClient.gd"
}, {
"base": &"Node",
"class": &"WebSocketServer",
"icon": "",
"language": &"GDScript",
"path": "res://websocket/WebSocketServer.gd"
}])
             RIFF  WEBPVP8L  /���m$���=�������}�;�^�O���w�4���]���=߮LP,ь�2�f-ݬ�3�4��
{Jo7�t�+�>����r��߿8�m۶ڶm۶m�f��}r�٣�NO�س5����x����\y�n����U�i�l+�.�_R���+����ȶմ��lt$��5���IR$�_�a&_ W EV��H�\vw��p�"w	�^��D� /����ٞE��w�������Ƶ��p�r�mI�O�����}�F���������ut[۶���Ԁ�!]Xc��S�����l7nI5���1�R�����rO�sQ��l��1ŷ�Q�λP)�kn��o!���3L��[᪇J��X�6_G�%�B0ǜ~"��4�(�SN�\vj����n8"P�K���K�r�O�aSu�C{����j��������ʿ�T�N8�F��G��g�@@��3�\�z ��K��<�`�Rm,��ZDRY��)IĊ��*�TO{�H�=�8)�F��"��-�k�z�s6��F:��%�M�;���fY�6��Q��&��pJ׻�
���d2y��l�sjA���{�sYS$���"�n  �qY�@�؉$�ldf�,|r��C)G`�5���\�N!@��f�C{J�:������ F�e;��w�v8���Yx����
 L�X%���d:}
 f*ҝ�*�[�����U�HC���|�����nK�����Ӣ� Ɣe��)���+�!��Y��;�5�Px=j��E=k	����������^���hRV~M�
zF���p�S̀�A�Ť�\M� �mf�>�en��Ž	U3�e�9�=]#���n����o��[󵁿 ��.��o{#��
�V�[,Fb�մ�J(~�ݸ�L��������<�%����3> V��roS�`���a�d���AK,֫f�}Z�A��a�j6AǷ��3�@5�z5��L��z+o��+����a���Xʔ �F����J�E�U]ğF��#p[+� ]y-�� 	{tv<��-r5�* �i�l�G-hj���&i��Z��u��.x�\��5��%���<�E3��{�WO3��\��KK�[�6x��f
�XE :0��(K��ָq�چ�`�Ȁ���T����2��_��<+͕ܧ��w�U��mR�0�*��mI� �֮v�ioKr��g�ݗ=����#�i����o����#
��Rh��M)�'/��皮=}ۆ4�w�ڲ�W��ڳ�?��Oe(6Xh5i%�����l�$B�ߤm-$�4� ;�i3��٪�
�_lV�XA�&��-\�L:�� @��u�
���i��by[�����6����J��i'��?>T��k�GL,����/�G�&��Q�Bߨ�SH_b��w5�� PU 殕pݯ�	��H�骦�k����N�.�
�g��r߿��B�����!�I�=�b�%�'�=��Jr���i�����-��v��:u������b���d�5����6\�����J{�`���/ 0���7��� ��J�)�Ҽ@���_�o�,X��g���xv趕�v��$�� �y���2��#03�G9��tI��sh�XJ���Nlh���|-�s_�� �_��'00O�4g	�r B�P��V�y��k����Poݿ�t%$���'-�� �߈�a-�}����Vd�UPl3 ���eA�e�` J�;D$@���<��H �PA4�0H���F��� <Êe��3D������P�iK��~#U�+�a�
*_n�}h�F ��P_�s*X�5���)�_	`��`�
n������"g[H��;z��~���~��tI�V�4�T�e( �:8���<5 ����P�2��1�H��Ќٟ��u7��jE�nSFC��К��҆��B؟g�h3����y������ ���
�u���[<��D�����������J���e|.����,��Oז����im1�
-ǚ�s���7����'�����Xۧ�����̖Ot�������)-s�����P��|��������M^g�`H5� �B8N��$>z���iF� ���p����Ԯ��7u|{�S���#
�az��Y��lS�]j��vW��=*��}Uoך�so��N�M���d'<c��+���G~���=>!ĀɐT��0	�w�+kL�_�@�`�`���	�~f�v.ȗ�RrL7���؀�<|Ŷ��f�� l5\����ӷ�����`�M]`���n�$1�}�L�vu	�w�;{_ ����_��E�A��	�b�|_�	�J���KyJ'
ڑ���b�g��ަ���_�˳0<�F6B��Q��:1x�V��T�乚{]��O����l�D[p%����ap�	�3MPa��0�f�ǖ�ga��CP���g�\@�C����j�y?�����6�;Nʜd����g�#�����0~��W�3Y�%w�V�/ ��~�ܤ�`|��U��44*�W�cI;Q��z_u<�
���(y� �����?0�@�I�{(�h`P,��7yP"�b��`�p��!�X����@��X2w�/4�tI뾎��k��Y��^r�����@��Z6w�!�ty׹f��ߴ��Z�~�S�X���%g���� �i,��d���I$6+K fHUd3�Vt=D���'�h��ӕ�oY�!p�x����N�,o��:=6��Uu�j�]mL��}��7Ѝ~R�CWp9�Sp5}��c~ `P�R��Q���K_+�4AФ&��f�������#��
Ħ��)���V�/q�J̝d�	��c$AR�%}���:�}
��F&:��������|��Ŷl�;��K�}���ITB��j�� �$���my�<`���=�������E��ݏk���B�+���*�(��z��h��v���9ȕ���7�UbLy���6�J���>W_�'ώ�{];#��J�Tw�nH���y�O�������            �?g?
;Z   res://chat.tscn�@"�CC�   res://client.tscn��	{��z   res://combo.tscnT��jT3R2   res://icon.webp�P���E1   res://server.tscn.U�)�s!"   res://WebSocket Chat Demo.icon.png�O\�n�J.   res://WebSocket Chat Demo.apple-touch-icon.png�AJ���^   res://WebSocket Chat Demo.png               ECFG
      application/config/name         WebSocket Chat Demo    application/config/description�      �   This is a demo of a simple chat implemented using WebSockets, showing both how to host a websocket server from Godot and how to connect to it.     application/config/tags0   "         demo       network 	   official       application/run/main_scene         res://combo.tscn   application/config/features   "         4.2    application/config/icon         res://icon.webp    display/window/stretch/mode         canvas_items   display/window/stretch/aspect         expand  #   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility   