class TeacherApp {
  constructor() {
    this.socket = null;
    this.localStream = null;
    this.peerConnections = new Map();
    this.roomCode = null;
    this.isStreaming = false;
    this.serverUrl = 'http://localhost:3000';

    this.initElements();
    this.bindEvents();
    this.log('Sistema iniciado', 'info');
  }

  qs(id) { return document.getElementById(id); } 
  log(msg, type = 'info') {
    const log = document.createElement('div');
    log.className = `log-entry ${type}`;
    log.innerHTML = `<span class="timestamp">[${new Date().toLocaleTimeString()}]</span>
                     <span class="message">${msg}</span>`;
    this.els.logs.appendChild(log);
    this.els.logs.scrollTop = this.els.logs.scrollHeight;
  }

  initElements() {
    this.els = {
      serverUrl: this.qs('serverUrl'),
      createRoom: this.qs('createRoomBtn'),
      setup: this.qs('setupSection'),
      control: this.qs('controlSection'),
      roomCode: this.qs('roomCodeDisplay'),
      copyCode: this.qs('copyCodeBtn'),
      studentCount: this.qs('studentCount'),
      start: this.qs('startStreamBtn'),
      stop: this.qs('stopStreamBtn'),
      endClass: this.qs('endClassBtn'),
      video: this.qs('localVideo'),
      overlay: this.qs('videoOverlay'),
      logs: this.qs('logsContainer'),
      clearLogs: this.qs('clearLogsBtn'),
      status: this.qs('status'),
      modal: this.qs('confirmModal'),
      modalMsg: this.qs('modalMessage'),
      modalConfirm: this.qs('modalConfirm'),
      modalCancel: this.qs('modalCancel'),
      modalClose: this.qs('modalClose')
    };
  }

  bindEvents() {
    const { createRoom, copyCode, start, stop, endClass, clearLogs,
            modalCancel, modalClose, modal, modalConfirm } = this.els;

    createRoom.onclick = () => this.createRoom();
    copyCode.onclick = () => this.copyCode();
    start.onclick = () => this.startStream();
    stop.onclick = () => this.stopStream();
    endClass.onclick = () => this.showModal('Encerrar aula?', () => this.endClass());
    clearLogs.onclick = () => this.clearLogs();

    [modalCancel, modalClose].forEach(btn => btn.onclick = () => this.hideModal());
    modal.onclick = e => { if (e.target === modal) this.hideModal(); };

    document.addEventListener('keydown', e => {
      if (e.ctrlKey && e.key === 'Enter')
        this.isStreaming ? this.stopStream() : this.startStream();
    });
  }

  status(state, text) {
    this.els.status.querySelector('.status-dot').className = `status-dot ${state}`;
    this.els.status.querySelector('.status-text').textContent = text;
  }

  clearLogs() {
    this.els.logs.innerHTML = '';
    this.log('Logs limpos');
  }

  showModal(msg, onConfirm) {
    this.els.modalMsg.textContent = msg;
    this.els.modal.style.display = 'block';
    this.els.modalConfirm.onclick = () => { this.hideModal(); onConfirm(); };
  }
  hideModal() { this.els.modal.style.display = 'none'; }

  async createRoom() {
    try {
      this.serverUrl = this.els.serverUrl.value.trim() || this.serverUrl;
      this.log(`Conectando a ${this.serverUrl}`);
      this.btnLoading(this.els.createRoom, true, 'Criando...');

      const res = await fetch(`${this.serverUrl}/create-room`, { method: 'POST' });
      if (!res.ok) throw new Error(`Erro ${res.status}`);
      this.roomCode = (await res.json()).roomCode;

      await this.connect();
      this.els.roomCode.textContent = this.roomCode;
      this.toggleSections();
      this.log(`Sala criada: ${this.roomCode}`, 'success');
      this.status('online', 'Sala Criada');

    } catch (err) {
      this.log(`Erro ao criar sala: ${err.message}`, 'error');
      this.btnLoading(this.els.createRoom, false, '<i class="fas fa-plus"></i> Criar Sala de Aula');
    }
  }

  connect() {
    return new Promise((resolve, reject) => {
      this.socket = io(this.serverUrl);

      this.socket.on('connect', () => {
        this.log('Conectado ao servidor', 'success');
        this.socket.emit('teacher-join', { roomCode: this.roomCode });
      });

      this.socket.on('joined-room', d => { this.log(`Entrou na sala ${d.roomCode}`, 'success'); resolve(); });
      this.socket.on('student-joined', d => this.onStudentJoin(d));
      this.socket.on('student-left', d => this.onStudentLeave(d));

      this.socket.on('answer', async d => {
        const pc = this.peerConnections.get(d.senderId);
        if (pc) {
          await pc.setRemoteDescription(new RTCSessionDescription(d.answer));
          this.log(`Resposta de ${d.senderId}`, 'success');
        }
      });

      this.socket.on('ice-candidate', d => {
        const pc = this.peerConnections.get(d.senderId);
        if (pc && d.candidate) pc.addIceCandidate(new RTCIceCandidate(d.candidate));
      });

      this.socket.on('error', d => { this.log(`Erro: ${d.message}`, 'error'); reject(d); });
      this.socket.on('disconnect', () => { this.log('Desconectado', 'warning'); this.status('offline', 'Desconectado'); });
    });
  }

  async copyCode() {
    try {
      await navigator.clipboard.writeText(this.roomCode);
      this.els.copyCode.innerHTML = '<i class="fas fa-check"></i>';
      this.log('Código copiado', 'success');
      setTimeout(() => this.els.copyCode.innerHTML = '<i class="fas fa-copy"></i>', 2000);
    } catch { this.log('Erro ao copiar código', 'error'); }
  }

  async startStream() {
    try {
      this.log('Iniciando captura...', 'info');
      this.btnLoading(this.els.start, true, 'Iniciando...');

      this.localStream = await navigator.mediaDevices.getDisplayMedia({
        video: { width: { ideal: 1920 }, height: { ideal: 1080 }, frameRate: { ideal: 30 } },
        audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true }
      });

      this.els.video.srcObject = this.localStream;
      this.els.overlay.style.display = 'none';

      this.localStream.getVideoTracks()[0].addEventListener('ended', () => this.stopStream());

      this.socket.emit('start-stream', { roomCode: this.roomCode });
      this.isStreaming = true;
      this.toggleStreamButtons(true);
      this.log('Transmissão iniciada', 'success');
      this.status('streaming', 'Transmitindo');
    } catch (err) {
      this.log(`Erro ao iniciar transmissão: ${err.message}`, 'error');
      this.btnLoading(this.els.start, false, '<i class="fas fa-play"></i> Iniciar Transmissão');
    }
  }

  stopStream() {
    this.localStream?.getTracks().forEach(t => t.stop());
    this.localStream = null;

    this.peerConnections.forEach(pc => pc.close());
    this.peerConnections.clear();

    Object.assign(this.els, {
      video: this.els.video.srcObject = null,
      overlay: this.els.overlay.style.display = 'flex'
    });

    this.toggleStreamButtons(false);
    this.socket?.emit('stop-stream', { roomCode: this.roomCode });
    this.isStreaming = false;
    this.log('Transmissão encerrada');
    this.status('online', 'Sala Criada');
  }

  endClass() {
    this.stopStream();
    this.socket?.disconnect();
    this.toggleSections(false);
    this.els.studentCount.textContent = '0';
    this.roomCode = null;
    this.log('Aula encerrada');
    this.status('offline', 'Desconectado');
  }

  async createPeerConnection(id) {
const pc = new RTCPeerConnection({
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    {
      urls: 'turn:meu-turn-server.com:3478',
      username: 'usuario',
      credential: 'senha'
    }
  ]
});

    this.localStream?.getTracks().forEach(t => pc.addTrack(t, this.localStream));

    pc.onicecandidate = e => e.candidate && this.socket.emit('ice-candidate', { candidate: e.candidate, targetId: id });
    pc.onconnectionstatechange = () => this.log(`Conexão ${id}: ${pc.connectionState}`);

    try {
      const offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      this.socket.emit('offer', { roomCode: this.roomCode, offer, targetId: id });
      this.peerConnections.set(id, pc);
      this.log(`Oferta enviada para ${id}`);
    } catch (err) { this.log(`Erro oferta ${id}: ${err.message}`, 'error'); }
  }

  onStudentJoin(d) {
    this.log(`Aluno conectado (${d.studentId})`);
    this.els.studentCount.textContent = d.studentCount;
    if (this.isStreaming) this.createPeerConnection(d.studentId);
  }
  onStudentLeave(d) {
    this.log(`Aluno saiu (${d.studentId})`, 'warning');
    this.els.studentCount.textContent = d.studentCount;
    this.peerConnections.get(d.studentId)?.close();
    this.peerConnections.delete(d.studentId);
  }

  toggleSections(connected = true) {
    this.els.setup.style.display = connected ? 'none' : 'block';
    this.els.control.style.display = connected ? 'block' : 'none';
    this.btnLoading(this.els.createRoom, false, '<i class="fas fa-plus"></i> Criar Sala de Aula');
  }

  toggleStreamButtons(streaming) {
    this.els.start.style.display = streaming ? 'none' : 'inline-flex';
    this.els.stop.style.display = streaming ? 'inline-flex' : 'none';
    this.els.start.disabled = false;
    if (!streaming) this.els.start.innerHTML = '<i class="fas fa-play"></i> Iniciar Transmissão';
  }

  btnLoading(btn, loading, text) {
    btn.disabled = loading;
    btn.innerHTML = loading ? `<i class="fas fa-spinner fa-spin"></i> ${text}` : text;
  }
}

document.addEventListener('DOMContentLoaded', () => new TeacherApp());
