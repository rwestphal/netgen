module Netgen
  class LinuxNamespace
    attr_accessor :pid

    # Create a child process running on a separate network and mount namespace.
    def fork_and_unshare
      begin
        io_in, io_out = IO.pipe

        pid = Kernel.fork do
          unshare(LibC::CLONE_NEWNS | LibC::CLONE_NEWPID | LibC::CLONE_NEWNET)

          # Fork again to use the new PID namespace.
          # Need to supress a warning that is irrelevant for us.
          warn_level = $VERBOSE
          $VERBOSE = nil
          pid = Kernel.fork do
            # HACK: kill when parent dies
            trap(:SIGUSR1) do
              LibC.prctl(LibC::PR_SET_PDEATHSIG, 15, 0, 0, 0)
              trap(:SIGUSR1, :IGNORE)
            end
            LibC.prctl(LibC::PR_SET_PDEATHSIG, 10, 0, 0, 0)

            mount_propagation(LibC::MS_REC | LibC::MS_PRIVATE)
            mount_proc
            yield
          end
          $VERBOSE = warn_level
          io_out.puts "#{pid}"
          exit(0)
        end

        @pid = io_in.gets.to_i
        Process.waitpid(pid)
      rescue SystemCallError => e
        $stderr.puts "System call error:: #{e.message}"
        $stderr.puts e.backtrace
        exit(1)
      end
    end

    # Set the mount propagation of the process.
    def mount_propagation(flags)
      mount('none', '/', nil, flags, nil)
    end

    # Mount the proc filesystem (useful after creating a new PID namespace)
    def mount_proc
      mount('none', '/proc', nil, LibC::MS_REC | LibC::MS_PRIVATE, nil)
      mount('proc', '/proc', 'proc',
            LibC::MS_NOSUID | LibC::MS_NOEXEC | LibC::MS_NODEV, nil)
    end

    # Switch current process's network namespace.
    # The mount namespace (CLONE_NEWNS) can't be changed using setns(2) because
    # some ruby interpreters run as multithread applications. The setns(2)'s
    # man page says the following: "A process may not be reassociated with a
    # new mount namespace if it is multithreaded".
    def switch_net_namespace
      setns(LibC::CLONE_NEWNET, @pid)
      yield
    ensure
      setns(LibC::CLONE_NEWNET, 1)
    end

    # Wrapper for mount(2)
    def mount(source, target, fs_type, flags, data)
      if LibC.mount(source, target, fs_type, flags, data) < 0
        raise SystemCallError.new('mount failed', FFI::LastError.error)
      end
    end

    # Wrapper for unshare(2).
    def unshare(flags)
      if LibC.unshare(flags) < 0
        raise SystemCallError.new('unshare failed', FFI::LastError.error)
      end
    end

    # Wrapper for setns(2).
    def setns(nstype, pid)
      path = "/proc/#{pid}/ns/net"
      File.open(path) do |file|
        if LibC.setns(file.fileno, nstype) < 0
          raise SystemCallError.new('setns failed', FFI::LastError.error)
        end
      end
    end
  end
end
