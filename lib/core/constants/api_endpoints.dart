class ApiEndpoints {
  ApiEndpoints._();

  // Core & System
  static const String systemInfo = '/api/v2.0/system/info';
  static const String systemGeneral = '/api/v2.0/system/general';
  static const String systemReboot = '/api/v2.0/system/reboot';
  static const String systemShutdown = '/api/v2.0/system/shutdown';
  static const String bootState = '/api/v2.0/boot/get_state';
  static const String deviceInfo = '/api/v2.0/device/get_info';

  // Telemetry & Reporting
  static const String reportingNetdata = '/api/v2.0/reporting/netdata_get_data';
  static const String reportingGraphs = '/api/v2.0/reporting/graphs';

  // Storage, Disks & Snapshots
  static const String pool = '/api/v2.0/pool';
  static const String poolDataset = '/api/v2.0/pool/dataset';
  static const String poolSnapshot = '/api/v2.0/pool/snapshot';
  static const String poolSnapshotTask = '/api/v2.0/pool/snapshottask';
  static const String poolScrub = '/api/v2.0/pool/scrub';
  static const String disk = '/api/v2.0/disk';
  static const String diskTemperatures = '/api/v2.0/disk/temperatures';

  // Apps
  static const String app = '/api/v2.0/app';
  static const String dockerStatus = '/api/v2.0/docker/status';

  // Filesystem & ACL
  static const String filesystemStat = '/api/v2.0/filesystem/stat';
  static const String filesystemStatFs = '/api/v2.0/filesystem/statfs';
  static const String filesystemListDir = '/api/v2.0/filesystem/listdir';
  static const String filesystemGetAcl = '/api/v2.0/filesystem/getacl';
  static const String filesystemSetAcl = '/api/v2.0/filesystem/setacl';
  static const String filesystemChown = '/api/v2.0/filesystem/chown';
  static const String filesystemAclTemplates = '/api/v2.0/filesystem/acltemplate/by_path';

  // System Management
  static const String alertList = '/api/v2.0/alert/list';
  static const String alertDismiss = '/api/v2.0/alert/dismiss';
  static const String alertRestore = '/api/v2.0/alert/restore';
  static const String sharingSmb = '/api/v2.0/sharing/smb';
  static const String sharingNfs = '/api/v2.0/sharing/nfs';
  static const String service = '/api/v2.0/service';
  static const String coreJobs = '/api/v2.0/core/get_jobs';
  static const String coreJobAbort = '/api/v2.0/core/job_abort';
  static const String audit = '/api/v2.0/audit';
  static const String updateCheck = '/api/v2.0/update/check_available';
  static const String sensor = '/api/v2.0/sensor';
  static const String coreSessions = '/api/v2.0/core/sessions';
  static const String users = '/api/v2.0/user';
  static const String groups = '/api/v2.0/group';
  static const String networkInterface = '/api/v2.0/interface';
}
