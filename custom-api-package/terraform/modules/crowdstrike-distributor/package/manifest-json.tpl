{
    "schemaVersion" : "2.0",
    "publisher"     : "Crowdstrike Inc.",
    "description"   : "CrowdStrike custom Install Package",
    "version"       : "1.0",
    "packages"      : {
      "amazon"       : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "centos"       : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "debian"       : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "opensuse"     : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "opensuseleap" : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "oracle"       : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "redhat"       : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "suse"         : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "ubuntu"       : {"_any": {"_any": { "file": "${prefix}-linux.zip"}}},
      "windows"      : {"_any": {"_any": { "file": "${prefix}-windows.zip"}}}
    },
    "files" : {
      "${prefix}-linux.zip": {
        "checksums" : {
          "sha256": "${linux_sha256}"
        }
      },
      "${prefix}-windows.zip": {
        "checksums" : {
          "sha256": "${windows_sha256}"
        }
      }
    }
}