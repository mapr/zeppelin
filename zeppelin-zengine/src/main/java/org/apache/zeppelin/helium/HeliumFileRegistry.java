package org.apache.zeppelin.helium;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.List;

import com.google.gson.Gson;
import com.sun.jndi.toolkit.url.Uri;


/**
 * This registry reads helium package json data
 * from specified local file url.
 *
 * File should be look like
 * [
 *    "packageName": {
 *       "0.0.1": json serialized HeliumPackage class,
 *       "0.0.2": json serialized HeliumPackage class,
 *       ...
 *    },
 *    ...
 * ]
 */
public class HeliumFileRegistry extends HeliumRegistry {
  private Gson gson;

  public HeliumFileRegistry(String name, String uri) {
    super(name, uri);
    this.gson = new Gson();
  }

  @Override
  public List<HeliumPackage> getAll() throws IOException {
    Uri fileUri = new Uri(uri());
    File path = new File(fileUri.getPath());
    InputStream fileInputStream = new FileInputStream(path);

    return HeliumJsonUtils.parsePackages(fileInputStream, gson);
  }
}
