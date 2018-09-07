/*
 * Licensed to the Apache Software Foundation (ASF) under one or more
 * contributor license agreements.  See the NOTICE file distributed with
 * this work for additional information regarding copyright ownership.
 * The ASF licenses this file to You under the Apache License, Version 2.0
 * (the "License"); you may not use this file except in compliance with
 * the License.  You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
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
