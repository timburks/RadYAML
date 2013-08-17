;;
;; Nukefile for RadYAML
;;
;; Commands:
;;	nuke 		- builds RadYAML as a framework
;;	nuke test	- runs the unit tests in the NuTests directory
;;	nuke install	- installs RadYAML in /Library/Frameworks
;;	nuke clean	- removes build artifacts
;;	nuke clobber	- removes build artifacts and RadYAML.framework
;;
;; The "nuke" build tool is installed with Nu (http://programming.nu)
;;

;; the @variables below are instance variables of a NukeProject.
;; for details, see tools/nuke in the Nu source distribution.

;; source files
(set @m_files     (filelist "^objc/.*.m$"))
(set @c_files     (filelist "^objc/.*.c$"))

(set SYSTEM ((NSString stringWithShellCommand:"uname") chomp))

(case SYSTEM
      ("Darwin"
               (set @arch (list "x86_64"))
               (set @cflags "-g -std=gnu99")
               (set @mflags "-fobjc-arc ")
               (set @ldflags "-framework Foundation"))
      ("Linux"
              (set @arch (list "i386"))
              (set gnustep_flags ((NSString stringWithShellCommand:"gnustep-config --objc-flags") chomp))
              (set gnustep_libs ((NSString stringWithShellCommand:"gnustep-config --base-libs") chomp))
              (set @cflags "-g -std=gnu99 -DLINUX -I/usr/local/include #{gnustep_flags}")
              (set @ldflags "#{gnustep_libs}"))
      (else nil))


;; framework description
(set @framework "RadYAML")
(set @framework_identifier   "com.radtastical.yaml")
(set @framework_creator_code "????")


(compilation-tasks)
(framework-tasks)

(task "clobber" => "clean" is
      (SH "rm -rf #{@framework_dir}")) ;; @framework_dir is defined by the nuke framework-tasks macro

(task "default" => "framework")

