package org.apache.zeppelin.helium;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

import org.apache.commons.io.FileUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.google.gson.Gson;
import com.google.gson.reflect.TypeToken;

/**
 * Utils for Helium
 */
public class HeliumJsonUtils {
  private static final Gson gson = new Gson();

  public static List<HeliumPackage> parsePackages(InputStream in, Gson gson) throws IOException {
    List<HeliumPackage> packageList = new LinkedList<>();

    BufferedReader reader;
    reader = new BufferedReader(
            new InputStreamReader(in));

    List<Map<String, Map<String, HeliumPackage>>> packages = gson.fromJson(
            reader,
            new TypeToken<List<Map<String, Map<String, HeliumPackage>>>>() {}.getType());
    reader.close();

    for (Map<String, Map<String, HeliumPackage>> pkg : packages) {
      for (Map<String, HeliumPackage> versions : pkg.values()) {
        packageList.addAll(versions.values());
      }
    }
    return packageList;
  }
}
