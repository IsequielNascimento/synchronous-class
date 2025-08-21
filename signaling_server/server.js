const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');

const app = express();
const server = http.createServer(app);

// Configurar CORS para permitir conexões de qualquer origem
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());

// Armazenar as salas de aula ativas
const activeRooms = new Map();

// Gerar código de 6 dígitos para a aula
function generateRoomCode() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Endpoint para criar uma nova sala de aula
app.post('/create-room', (req, res) => {
  const roomCode = generateRoomCode();
  const roomId = uuidv4();
  
  activeRooms.set(roomCode, {
    id: roomId,
    teacher: null,
    students: new Set(),
    isActive: false,
    createdAt: new Date()
  });
  
  console.log(`Nova sala criada: ${roomCode}`);
  res.json({ roomCode, roomId });
});

// Endpoint para verificar se uma sala existe
app.get('/room/:code', (req, res) => {
  const roomCode = req.params.code;
  const room = activeRooms.get(roomCode);
  
  if (room) {
    res.json({ 
      exists: true, 
      isActive: room.isActive,
      studentCount: room.students.size 
    });
  } else {
    res.json({ exists: false });
  }
});

// Endpoint paralistar salas ativas
app.get('/active-rooms', (req, res) => {
  const rooms = Array.from(activeRooms.entries()).map(([code, room]) => ({
    code,
    isActive: room.isActive,
    studentCount: room.students.size,
    createdAt: room.createdAt
  }));
  res.json(rooms);
});

io.on('connection', (socket) => {
  console.log('Cliente conectado:', socket.id);
  
  // Professor se junta à sala
  socket.on('teacher-join', (data) => {
    const { roomCode } = data;
    const room = activeRooms.get(roomCode);
    
    if (room) {
      room.teacher = socket.id;
      socket.join(roomCode);
      socket.roomCode = roomCode;
      socket.userType = 'teacher';
      
      console.log(`Professor ${socket.id} entrou na sala ${roomCode}`);
      socket.emit('joined-room', { roomCode, userType: 'teacher' });
    } else {
      socket.emit('error', { message: 'Sala não encontrada' });
    }
  });
  
  // Aluno se junta à sala
  socket.on('student-join', (data) => {
    const { roomCode } = data;
    const room = activeRooms.get(roomCode);
    
    if (room) {
      room.students.add(socket.id);
      socket.join(roomCode);
      socket.roomCode = roomCode;
      socket.userType = 'student';
      
      console.log(`Aluno ${socket.id} entrou na sala ${roomCode}`);
      socket.emit('joined-room', { roomCode, userType: 'student' });
      
      // Notificar o professor sobre o novo aluno
      if (room.teacher) {
        io.to(room.teacher).emit('student-joined', { 
          studentId: socket.id,
          studentCount: room.students.size 
        });
      }
    } else {
      socket.emit('error', { message: 'Sala não encontrada' });
    }
  });
  
  // Professor inicia a transmissão
  socket.on('start-stream', (data) => {
    const { roomCode } = data;
    const room = activeRooms.get(roomCode);
    
    if (room && room.teacher === socket.id) {
      room.isActive = true;
      console.log(`Transmissão iniciada na sala ${roomCode}`);
      socket.to(roomCode).emit('stream-started');
    }
  });
  
  // Professor encerra a transmissão
  socket.on('stop-stream', (data) => {
    const { roomCode } = data;
    const room = activeRooms.get(roomCode);
    
    if (room && room.teacher === socket.id) {
      room.isActive = false;
      console.log(`Transmissão encerrada na sala ${roomCode}`);
      socket.to(roomCode).emit('stream-stopped');
    }
  });
  
  // Sinalização WebRTC - Oferta do professor
  socket.on('offer', (data) => {
    const { roomCode, offer, targetId } = data;
    console.log(`Oferta recebida na sala ${roomCode} para ${targetId || 'todos'}`);
    
    if (targetId) {
      // Enviar oferta para um aluno específico
      io.to(targetId).emit('offer', { offer, senderId: socket.id });
    } else {
      // Enviar oferta para todos os alunos na sala
      socket.to(roomCode).emit('offer', { offer, senderId: socket.id });
    }
  });
  
  // Sinalização WebRTC - Resposta do aluno
  socket.on('answer', (data) => {
    const { answer, targetId } = data;
    console.log(`Resposta recebida de ${socket.id} para ${targetId}`);
    
    io.to(targetId).emit('answer', { answer, senderId: socket.id });
  });
  
  // Sinalização WebRTC - Candidatos ICE
  socket.on('ice-candidate', (data) => {
    const { candidate, targetId } = data;
    console.log(`Candidato ICE de ${socket.id} para ${targetId || 'sala'}`);
    
    if (targetId) {
      io.to(targetId).emit('ice-candidate', { candidate, senderId: socket.id });
    } else {
      socket.to(socket.roomCode).emit('ice-candidate', { candidate, senderId: socket.id });
    }
  });
  
  // Desconexão
  socket.on('disconnect', () => {
    console.log('Cliente desconectado:', socket.id);
    
    if (socket.roomCode) {
      const room = activeRooms.get(socket.roomCode);
      
      if (room) {
        if (socket.userType === 'teacher' && room.teacher === socket.id) {
          // Professor desconectou - encerrar a sala
          room.teacher = null;
          room.isActive = false;
          socket.to(socket.roomCode).emit('teacher-disconnected');
          console.log(`Professor desconectou da sala ${socket.roomCode}`);
        } else if (socket.userType === 'student') {
          // Aluno desconectou
          room.students.delete(socket.id);
          
          // Notificar o professor
          if (room.teacher) {
            io.to(room.teacher).emit('student-left', { 
              studentId: socket.id,
              studentCount: room.students.size 
            });
          }
          console.log(`Aluno desconectou da sala ${socket.roomCode}`);
        }
        
        // Remover sala se estiver vazia
        if (!room.teacher && room.students.size === 0) {
          activeRooms.delete(socket.roomCode);
          console.log(`Sala ${socket.roomCode} removida (vazia)`);
        }
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Servidor de sinalização rodando na porta ${PORT}`);
  console.log(`Acesse http://localhost:${PORT} para verificar o status`);
});

// Endpoint de status
app.get('/', (req, res) => {
  res.json({
    message: 'Servidor de Sinalização WebRTC para Aulas ao Vivo',
    status: 'online',
    activeRooms: activeRooms.size,
    timestamp: new Date().toISOString()
  });
});

// Limpeza periódica de salas antigas
setInterval(() => {
  const now = new Date();
  const maxAge = 24 * 60 * 60 * 1000; // 24 horas
  
  for (const [code, room] of activeRooms.entries()) {
    if (now - room.createdAt > maxAge && !room.isActive && room.students.size === 0) {
      activeRooms.delete(code);
      console.log(`Sala ${code} removida por inatividade`);
    }
  }
}, 60 * 60 * 1000); // Executar a cada hora

