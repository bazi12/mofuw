import ctx, ctxpool, sysutils
import httputils
import net, nativesockets, asyncdispatch

when defined(windows):
  from winlean import TCP_NODELAY
else:
  from posix import TCP_NODELAY

proc updateTime(fd: AsyncFD): bool =
  updateServerTime()
  return false

proc newServerSocket*(port: int): SocketHandle =
  let server = newSocket()
  server.setSockOpt(OptReuseAddr, true)
  server.setSockOpt(OptReusePort, true)
  server.getFD().setSockOptInt(cint(IPPROTO_TCP), TCP_NODELAY, 1)
  server.getFd.setBlocking(false)
  server.bindAddr(Port(port))
  server.listen(defaultBacklog().cint)
  return server.getFd()

proc initCtx*(ctx: MofuwCtx, fd: AsyncFD, ip: string): MofuwCtx =
  ctx.fd = fd
  ctx.ip = ip
  ctx.bufLen = 0
  ctx.respLen = 0
  ctx

proc mofuwServe*(ctx: ServeCtx) {.async.} =
  initCtxPool(ctx.readBufferSize, ctx.writeBufferSize, ctx.poolsize)

  let server = ctx.port.newServerSocket().AsyncFD
  register(server)
  setServerName(ctx.servername)
  updateServerTime()
  addTimer(1000, false, updateTime)

  var cantaccept = false

  while true:
    if unlikely cantaccept:
      await sleepAsync(10)
      cantaccept = true

    try:
      let (address, client) = await acceptAddr(server)
      let mCtx = getCtx(ctx.readBufferSize, ctx.writeBuffersize).initCtx(client, address)
      asyncCheck ctx.handler(mCtx)
    except:
      # TODO async sleep.
      # await sleepAsync(10)
      cantAccept = true
