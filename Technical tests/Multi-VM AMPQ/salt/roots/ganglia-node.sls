ganglia-node:
  pkg.installed:
    - name: ganglia-monitor
      
ganglia-monitor:
  service.running:
    - reload: True
    - watch:
      - file: Add node to cluster
      - file: Set udp_send_channel
      - file: Set udp_recv_channel
      - file: Set tcp_accept_channel
  
Add node to cluster:    
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: cluster {
    - marker_end: owner = "unspecified"
    - content: '  name = "Workers"'

Set udp_send_channel:
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "udp_send_channel {"
    - marker_end: "}"
    - content: "  port = 8557"
    - show_changes: True

Set udp_recv_channel: 
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "udp_recv_channel {" 
    - marker_end: "}"
    - content: "  port = 8557"
    - show_changes: True

Set tcp_accept_channel:
  file.blockreplace:
    - name: /etc/ganglia/gmond.conf
    - marker_start: "tcp_accept_channel {"
    - marker_end: "}"
    - content: "  port = 8557"

