> t <- read.csv("/Path/to/parsed.zfsio.csv", skip=1, sep=",")
> t[,1] <- as.POSIXct(h3l01[,1],  format="%Y-%m-%d-%T")

The following will plot first 70k data points. Adjust range to narrow down time.

> plot(t[,1][c(0:70000)],t[,2][c(0:70000)],type="l", lwd=0.1, xlab="Time", ylab="rd_iops")
> plot(t[,1][c(0:70000)],t[,3][c(0:70000)],type="l", lwd=0.1, xlab="Time", ylab="wr_iops")
> plot(t[,1][c(0:70000)],t[,4][c(0:70000)],type="l", lwd=0.1, xlab="Time", ylab="rd_thr")
> plot(t[,1][c(0:70000)],t[,5][c(0:70000)],type="l", lwd=0.1, xlab="Time", ylab="wr_thr")
> plot(t[,1][c(0:70000)],t[,6][c(0:70000)],type="l", lwd=0.1, xlab="Time", ylab="rd_bs")
> plot(t[,1][c(0:70000)],t[,7][c(0:70000)],type="l", lwd=0.1, xlab="Time", ylab="wr_bs")
