// @ts-check
const { spawn } = require("child_process");
const path = require("path");
const readline = require("readline");

class ODiffServer {
  /**
   * Create an ODiffServer instance
   * Server initialization starts immediately and is awaited automatically in compare()
   * @param {string | undefined} [binaryPath] - Optional path to odiff binary (defaults to bin/odiff.exe)
   */
  constructor(binaryPath) {
    this.binaryPath = binaryPath || path.join(__dirname, "bin", "odiff.exe");
    this.process = null;
    this.ready = false;
    this.pendingRequests = new Map();
    this.requestId = 0;
    this.exiting = false;

    // Start server initialization immediately
    /** @type {Promise | null} */
    this._initPromise = this._initialize();
  }

  /**
   * Internal method to initialize the server process
   * @private
   */
  async _initialize() {
    if (this.process) return;

    return new Promise((resolve, reject) => {
      try {
        this.process = spawn(this.binaryPath, ["--server"], {
          stdio: ["pipe", "pipe", "pipe"],
        });

        this.process.on("error", (err) => {
          this._initPromise = null;
          reject(new Error(`Failed to start odiff server: ${err.message}`));
        });

        this.process.on("exit", (code) => {
          if (!this.exiting) {
            console.warn(`odiff server exited unexpectedly with code ${code}`);
            // Reset for potential restart
            this._initPromise = null;
          }
          this.cleanup();
        });

        const rl = readline.createInterface({
          input: this.process.stdout,
          crlfDelay: Infinity,
        });

        rl.on("line", (line) => {
          try {
            const response = JSON.parse(line);

            // Handle ready signal
            if (response.ready && !this.ready) {
              this.ready = true;
              resolve(undefined);
              return;
            }

            // Handle responses with request ID matching
            if (!("requestId" in response)) {
              throw new Error("odiff: received message without requestId");
            }

            const pending = this.pendingRequests.get(response.requestId);
            if (pending) {
              this.pendingRequests.delete(response.requestId);
              if (pending.timeoutId !== undefined) {
                clearTimeout(pending.timeoutId);
              }

              pending.resolve(response);
            } else {
              console.warn(
                `Received response for unknown request ID: ${response.requestId}`,
              );
            }
          } catch (err) {
            console.error("Failed to parse server response:", line, err);
          }
        });

        if (!process.env.CI) {
          setTimeout(() => {
            if (!this.ready) {
              this.stop();
              this._initPromise = null;
              reject(
                new Error("odiff: server failed to start within 5 seconds"),
              );
            }
          }, 5000);
        }
      } catch (err) {
        this._initPromise = null;
        reject(err);
      }
    });
  }

  /**
   * Compare two images using the persistent server
   * Automatically waits for server initialization if needed
   *
   * @param {string} basePath - Path to base image
   * @param {string} comparePath - Path to comparison image
   * @param {string} diffOutput - Path to output diff image
   * @param {import("./odiff.d.ts").ODiffOptions & { timeout?: number }} [options] - Comparison options
   * @returns {Promise<Object>} Comparison result
   */
  async compare(basePath, comparePath, diffOutput, options = {}) {
    if (this._initPromise && !this.ready) {
      await this._initPromise;
    }

    // If server died and _initPromise was reset, reinitialize
    if (!this._initPromise && !this.ready) {
      this._initPromise = this._initialize();
      await this._initPromise;
    }

    return new Promise((resolve, reject) => {
      const requestId = this.requestId++;
      let timeoutId;
      if (options.timeout !== undefined) {
        timeoutId = setTimeout(() => {
          if (this.pendingRequests.has(requestId)) {
            this.pendingRequests.delete(requestId);
            reject(
              new Error(`odiff: Request timed out after ${options.timeout}ms`),
            );
          }
        }, options.timeout);
      }

      this.pendingRequests.set(requestId, { resolve, reject, timeoutId });
      const request = {
        requestId: requestId,
        base: basePath,
        compare: comparePath,
        output: diffOutput,
        options: {
          threshold: options.threshold,
          failOnLayoutDiff: options.failOnLayoutDiff,
          antialiasing: options.antialiasing,
          captureDiffLines: options.captureDiffLines,
          outputDiffMask: options.outputDiffMask,
        },
      };

      try {
        this.process?.stdin.write(JSON.stringify(request) + "\n");
      } catch (err) {
        this.pendingRequests.delete(requestId);
        if (timeoutId !== undefined) {
          clearTimeout(timeoutId);
        }
        reject(new Error(`odiff: Failed to send request: ${err.message}`));
      }
    });
  }

  /**
   * Internal cleanup method
   * @private
   */
  cleanup() {
    this.ready = false;
    this.process = null;
    this._initPromise = null;

    // Reject all pending requests and clear timeouts
    for (const [_, { reject, timeoutId }] of this.pendingRequests) {
      if (timeoutId !== undefined) {
        clearTimeout(timeoutId);
      }
      reject(new Error("odiff: Server process terminated"));
    }
    this.pendingRequests.clear();
  }

  /**
   * Stop the odiff server process
   * Safe to call even if server is not running
   */
  stop() {
    if (!this.process) return;

    this.exiting = true;
    try {
      this.process.stdin.end();
      this.process.kill();
    } catch (err) {
      // Ignore errors during shutdown
    }

    this.cleanup();
    this.exiting = false;
  }
}

module.exports = {
  ODiffServer,
};
