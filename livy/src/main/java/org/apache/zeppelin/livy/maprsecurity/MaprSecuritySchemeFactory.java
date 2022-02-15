package org.apache.zeppelin.livy.maprsecurity;

import org.apache.http.auth.AuthScheme;
import org.apache.http.auth.AuthSchemeProvider;
import org.apache.http.protocol.HttpContext;

class MaprSecuritySchemeFactory implements AuthSchemeProvider {
  @Override
  public AuthScheme create(HttpContext context) {
    return new MaprSecurityScheme();
  }
}
