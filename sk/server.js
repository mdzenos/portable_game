import { createServer } from "http";
import { Server } from "socket.io";

const PORT = process.env.SK_PORT || 8081;

// tạo HTTP server
const httpServer = createServer();

// tạo Socket.IO server
const io = new Server(httpServer, {
	cors: {
		origin: "*", // trong prod phải whitelist domain FE
		methods: ["GET", "POST"]
	}
});

// khi client connect
io.on("connection", (socket) => {
	console.log(`[SK] client connected: ${socket.id}`);

	// gửi welcome
	socket.emit("WELCOME", { ts: Date.now() });

	// echo test
	socket.on("ECHO", (msg) => {
		socket.emit("ECHO", { payload: msg, ts: Date.now() });
	});

	socket.on("disconnect", (reason) => {
		console.log(`[SK] client disconnected: ${socket.id} -> ${reason}`);
	});
});

// broadcast example (tick mỗi giây)
setInterval(() => {
	io.emit("TICK", { ts: Date.now() });
}, 1000);

httpServer.listen(PORT, () => {
	console.log(`[SK] listening on port ${PORT}`);
});
