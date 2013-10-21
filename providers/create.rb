action :create do

unless @new_resource.label
  label = @new_resource.name
else
  label = @new_resource.label
end
if @new_resource.file
  device = @new_resource.device
elsif @new_resource.vg
  device = "/dev/mapper/#{@new_resource.vg}-#{label}"
elsif @new_resource.uuid
  device = "/dev/disk/by-uuid/#{@new_resource.uuid}"
elsif @new_resource.device
  device = @new_resource.device
else
  device = "/dev/mapper/#{label}"
end
fstype = @new_resource.fstype
user = @new_resource.user
group = @new_resource.group
mode = @new_resource.mode
pass = @new_resource.pass
dump = @new_resource.dump
options = @new_resource.options

vg = @new_resource.vg
file = @new_resource.file
sparse = @new_resource.sparse
size = @new_resource.size

  # In two cases we may need to idempotently create the storage before creating the filesystem on it: LVM and file-backed.
  if ( ( @new_resource.vg || @new_resource.file ) && ( @new_resource.size != nil ) && ( @new_resource.mkstorage ) )

    # LVM
    if @new_resource.vg
      # We use the lvm provider directly.
      lvm_volume_group vg do
        logical_volume label do
          size size
        end
      end
    end

    # File-backed
    if @new_resource.file
      # We use the local filebackend provider, to which we feed some variables including the loopback device we want.
      filesystems_filebacked file do
        device device
        size size
        sparse sparse
      end
    end

  end

  # We only try and create a filesystem if the device is not mounted.
  unless is_mounted?(device)

    # We use this check to test if a file is mountable or not
    generic_check_cmd = "mkdir -p /tmp/filesystemchecks/#{label}; mount #{device} /tmp/filesystemchecks/#{label} && umount /tmp/filesystemchecks/#{label}"

    # Install the filesystem's default package and recipes as configured in attributes.
    fs_tools = node[:filesystems_tools][@new_resource.fstype]
    # One day Chef will support calling dynamic include_recipe from LWRPS but until then - see https://tickets.opscode.com/browse/CHEF-611
    # (fs_tools['recipe'].split(',') || []).each {|default_recipe| include_recipe #{default_recipe}"}
    if fs_tools['package']
      packages = fs_tools['package'].split(',')
      (packages || []).each {|default_package| package "#{default_package}"}
    end

    # If we were keyed to use specific package or cookbooks we attempt to install those too.
    # One day Chef will support calling dynamic include_recipe from LWRPS but until then - see https://tickets.opscode.com/browse/CHEF-611
    #if @new_resource.recipe
    #  (@new_resource.recipe.split(',') || []).each {|keyed_recipe| include_recipe "#{keyed_recipe}"}
    #end
    if @new_resource.package
      packages = @new_resource.package.split(',')
      (packages || []).each {|keyed_package| package "#{keyed_package}"}
    end

    log "filesystem #{label} creating #{fstype} on #{device}"

    # We form our mkfs command
    mkfs_cmd = "mkfs -t #{fstype} #{@new_resource.mkfs_options} -L #{label} #{device}"
  
    if @new_resource.force
 
     # We we create the filesystem without any checks, and we ignore failures. This is sparta, etc.
      execute mkfs_cmd do
        ignore_failure true
      end

    else

      # We create the filesystem, but only if the device does not already contain a mountable filesystem, and we have the tools
      execute mkfs_cmd do
        only_if "which mkfs.#{fstype}"
        not_if generic_check_cmd
      end

    end 

  end

  new_resource.updated_by_last_action(true)
end

# If we're enabling, we create the fstab entry.
action :enable do

unless @new_resource.label
  label = @new_resource.name
else
  label = @new_resource.label
end
if @new_resource.file
  device = @new_resource.device
elsif @new_resource.vg
  device = "/dev/mapper/#{@new_resource.vg}-#{label}"
elsif @new_resource.uuid
  device = "/dev/disk/by-uuid/#{@new_resource.uuid}"
elsif @new_resource.device
  device = @new_resource.device
else
  device = "/dev/mapper/#{label}"
end
fstype = @new_resource.fstype
user = @new_resource.user
group = @new_resource.group
mode = @new_resource.mode
pass = @new_resource.pass
dump = @new_resource.dump
options = @new_resource.options


  if @new_resource.mount

    # We use the chef directory method to create the mountpoint with the settings we provide
    directory @new_resource.mount do
      recursive true
      owner user if user
      group group if group
      mode mode if mode
    end

    # Mount using the chef resource
    mount @new_resource.mount do
      device device
      fstype fstype
      pass pass
      dump dump
      options options
      action :enable
      only_if "test -b #{device}"
    end

  end

end

# If we're mounting, we mount.
action :mount do

unless @new_resource.label
  label = @new_resource.name
else
  label = @new_resource.label
end
if @new_resource.file
  device = @new_resource.device
elsif @new_resource.vg
  device = "/dev/mapper/#{@new_resource.vg}-#{label}"
elsif @new_resource.uuid
  device = "/dev/disk/by-uuid/#{@new_resource.uuid}"
elsif @new_resource.device
  device = @new_resource.device
else
  device = "/dev/mapper/#{label}"
end
fstype = @new_resource.fstype
user = @new_resource.user
group = @new_resource.group
mode = @new_resource.mode
pass = @new_resource.pass
dump = @new_resource.dump
options = @new_resource.options

  if @new_resource.mount

    # We use the chef directory method to create the mountpoint with the settings we provide
    directory @new_resource.mount do
      recursive true
      owner user if user
      group group if group
      mode mode if mode
    end
    
    # Mount using the chef resource
    mount @new_resource.mount do
      device device
      fstype fstype
      options options
      action :mount
      only_if "test -b #{device}"
    end

  end

end