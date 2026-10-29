package com.ma.nasdash.smb

import android.content.Context
import jcifs.CIFSContext
import jcifs.config.PropertyConfiguration
import jcifs.context.BaseContext
import jcifs.smb.NtlmPasswordAuthenticator
import jcifs.smb.SmbFile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.Properties

class SmbManager(private val context: Context) {

    init {
        try {
            if (java.security.Security.getProvider("BC") !is org.bouncycastle.jce.provider.BouncyCastleProvider) {
                java.security.Security.removeProvider("BC")
                java.security.Security.insertProviderAt(org.bouncycastle.jce.provider.BouncyCastleProvider(), 1)
            }
        } catch (_: Exception) {}
    }

    private fun getCifsContext(username: String?, password: String?, domain: String?): CIFSContext {
        val props = Properties().apply {
            setProperty("jcifs.smb.client.enableSMB2", "true")
            setProperty("jcifs.smb.client.disableSMB1", "true")
            setProperty("jcifs.smb.client.minVersion", "SMB202")
            setProperty("jcifs.smb.client.maxVersion", "SMB311")
            setProperty("jcifs.smb.client.connTimeout", "5000")
            setProperty("jcifs.smb.client.soTimeout", "30000")
            setProperty("jcifs.smb.client.responseTimeout", "30000")
        }
        val config = PropertyConfiguration(props)
        val base = BaseContext(config)
        return if (!username.isNullOrEmpty()) {
            val auth = NtlmPasswordAuthenticator(domain ?: "", username, password ?: "")
            base.withCredentials(auth)
        } else {
            base.withAnonymousCredentials()
        }
    }

    private fun normalizeSmbUrl(host: String, share: String, path: String): String {
        var cleanPath = path.trim().replace('\\', '/')
        if (cleanPath.startsWith("/")) cleanPath = cleanPath.substring(1)
        val cleanShare = share.trim().trim('/')
        val url = StringBuilder("smb://$host/$cleanShare/")
        if (cleanPath.isNotEmpty()) {
            url.append(cleanPath)
            if (!cleanPath.endsWith("/")) url.append("/")
        }
        return url.toString()
    }

    suspend fun listFiles(
        host: String,
        share: String,
        path: String,
        username: String?,
        password: String?,
        domain: String?
    ): List<Map<String, Any>> = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val smbUrl = normalizeSmbUrl(host, share, path)
        val dir = SmbFile(smbUrl, cifsContext)
        val results = mutableListOf<Map<String, Any>>()

        val files = dir.listFiles() ?: emptyArray()
        for (f in files) {
            val isDir = f.isDirectory
            val name = f.name.trimEnd('/')
            val size = if (isDir) 0L else try { f.length() } catch (_: Exception) { 0L }
            val lastModified = try { f.lastModified() } catch (_: Exception) { 0L }

            results.add(
                mapOf(
                    "name" to name,
                    "path" to f.path,
                    "isDirectory" to isDir,
                    "size" to size,
                    "lastModified" to lastModified,
                    "canRead" to try { f.canRead() } catch (_: Exception) { true },
                    "canWrite" to try { f.canWrite() } catch (_: Exception) { true }
                )
            )
        }
        // Directories first, then alphabetical
        results.sortWith(compareByDescending<Map<String, Any>> { it["isDirectory"] as Boolean }.thenBy { (it["name"] as String).lowercase() })
        results
    }

    suspend fun createFolder(
        url: String,
        username: String?,
        password: String?,
        domain: String?
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val folderUrl = if (url.endsWith("/")) url else "$url/"
        val smbFile = SmbFile(folderUrl, cifsContext)
        if (!smbFile.exists()) {
            smbFile.mkdirs()
            true
        } else {
            false
        }
    }

    suspend fun rename(
        sourceUrl: String,
        newName: String,
        username: String?,
        password: String?,
        domain: String?
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val src = SmbFile(sourceUrl, cifsContext)
        val parent = src.parent ?: return@withContext false
        val destUrl = if (src.isDirectory) "$parent$newName/" else "$parent$newName"
        val dest = SmbFile(destUrl, cifsContext)
        src.renameTo(dest)
        true
    }

    suspend fun delete(
        url: String,
        username: String?,
        password: String?,
        domain: String?
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val target = SmbFile(url, cifsContext)
        if (target.exists()) {
            target.delete()
            true
        } else {
            false
        }
    }

    suspend fun copy(
        sourceUrl: String,
        destUrl: String,
        username: String?,
        password: String?,
        domain: String?
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val src = SmbFile(sourceUrl, cifsContext)
        val dest = SmbFile(destUrl, cifsContext)
        src.copyTo(dest)
        true
    }

    suspend fun move(
        sourceUrl: String,
        destUrl: String,
        username: String?,
        password: String?,
        domain: String?
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val src = SmbFile(sourceUrl, cifsContext)
        val dest = SmbFile(destUrl, cifsContext)
        try {
            src.renameTo(dest)
            true
        } catch (_: Exception) {
            // Fallback for cross-share moves
            src.copyTo(dest)
            src.delete()
            true
        }
    }

    suspend fun download(
        remoteUrl: String,
        localPath: String,
        username: String?,
        password: String?,
        domain: String?,
        onProgress: (Long, Long) -> Unit
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val remoteFile = SmbFile(remoteUrl, cifsContext)
        val totalBytes = remoteFile.length()
        val localFile = File(localPath)
        localFile.parentFile?.mkdirs()

        remoteFile.inputStream.use { input ->
            FileOutputStream(localFile).use { output ->
                val buffer = ByteArray(64 * 1024)
                var bytesRead: Int
                var downloaded = 0L
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    downloaded += bytesRead
                    onProgress(downloaded, totalBytes)
                }
            }
        }
        true
    }

    suspend fun upload(
        localPath: String,
        remoteUrl: String,
        username: String?,
        password: String?,
        domain: String?,
        onProgress: (Long, Long) -> Unit
    ): Boolean = withContext(Dispatchers.IO) {
        val cifsContext = getCifsContext(username, password, domain)
        val localFile = File(localPath)
        val totalBytes = localFile.length()
        val remoteFile = SmbFile(remoteUrl, cifsContext)

        FileInputStream(localFile).use { input ->
            remoteFile.outputStream.use { output ->
                val buffer = ByteArray(64 * 1024)
                var bytesRead: Int
                var uploaded = 0L
                while (input.read(buffer).also { bytesRead = it } != -1) {
                    output.write(buffer, 0, bytesRead)
                    uploaded += bytesRead
                    onProgress(uploaded, totalBytes)
                }
            }
        }
        true
    }
}
