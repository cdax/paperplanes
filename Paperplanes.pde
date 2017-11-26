
import toxi.geom.Vec3D;
import toxi.geom.ReadonlyVec3D;
import toxi.geom.mesh.TriangleMesh;
import toxi.geom.mesh.STLReader;
import toxi.processing.ToxiclibsSupport;

ToxiclibsSupport gfx;
TriangleMesh paperplaneMesh;
ArrayList<SteeredPaperplane> magentaPlanes, whitePlanes;
int numMagentaPlanes = 300, numWhitePlanes = 200;
color magenta, white;
float spin = radians(0.5);
float maxSpeed = 4;
float inSightDist = 200.00;
float tooCloseDist = 50.00;
Vec3D center, cam, targetBehindCam;

class Paperplane {
  Vec3D pos;
  Vec3D vel;
  float size;
  color fillColor;
  TriangleMesh mesh;
  Vec3D forward = new Vec3D(0, -1, 0);
  
  Paperplane(Vec3D pos_, Vec3D vel_, float size_, color fillColor_) {
    pos = pos_;
    vel = vel_;
    size = size_;
    fillColor = fillColor_;
    // grab a copy of the global paper plane model
    mesh = paperplaneMesh.copy();
  }
  
  void handleEdgeCollisions() {
    // what happens when the plane hits the bounds of its world? It bounces off!
    if(pos.x > width) {
      pos.x = width;
      vel.x *= -1;
    } else if(pos.x < 0) {
      pos.x = 0;
      vel.x *= -1;
    }
    if(pos.y > height) {
      pos.y = height;
      vel.y *= -1;
    } else if(pos.y < 0) {
      pos.y = 0;
      vel.y *= -1;
    }
    if(pos.z > cam.z - 50) {
      pos.z = cam.z - 50;
      vel.z *= -1;
    } else if(pos.z < -500) {
      pos.z = -500;
      vel.z *= -1;
    }
  }
  
  void update() {
    // make sure we're not moving TOO fast
    vel.limit(maxSpeed);
    // add a bit of spin around the velocity axis
    mesh = mesh.rotateAroundAxis(vel, spin);
    // and then move forward
    pos = pos.add(vel);
    // align the plane in the direction of its velocity
    Vec3D normalizedVelocity = vel.getNormalized();
    // interpolate for smooooooth steering!
    Vec3D dir = forward.interpolateTo(normalizedVelocity, 0.1);
    mesh = mesh.pointTowards(dir, forward);
    forward = dir;
    handleEdgeCollisions();
  }
  
  void display() {
    stroke(0);
    fill(fillColor);
    pushMatrix();
      translate(pos.x, pos.y, pos.z);
      scale(size);
      strokeWeight(0.05);
      gfx.mesh(mesh, true, 0);
    popMatrix();
  }
}

class SteeredPaperplane extends Paperplane {
  int maxForce = 1;
  Vec3D steeringForce;
  
  SteeredPaperplane(Vec3D pos_, Vec3D vel_, float size_, color fillColor_) {
    super(pos_, vel_, size_, fillColor_);
    steeringForce = new Vec3D();
  }
  
  void update() {
    steeringForce.limit(maxForce);
    steeringForce.normalizeTo(steeringForce.magnitude() / size);
    if(steeringForce.magnitude() > 0) {
      vel = vel.add(steeringForce);
    }
    steeringForce = new Vec3D();
    super.update();
  }
  
  void seek(Vec3D target) {
    Vec3D desiredVelocity = target.sub(pos);
    desiredVelocity.normalizeTo(maxSpeed);
    Vec3D force = desiredVelocity.sub(vel);
    steeringForce = steeringForce.add(force);
  }
  
  void flee(Vec3D target) {
    Vec3D desiredVelocity = target.sub(pos);
    desiredVelocity.normalizeTo(maxSpeed);
    Vec3D force = desiredVelocity.sub(vel);
    steeringForce = steeringForce.sub(force);
  }
  
  boolean isInSight(Paperplane plane) {
    if(pos.distanceTo(plane.pos) > inSightDist) return false;
    Vec3D heading = vel.getNormalized();
    Vec3D diff = plane.pos.sub(pos);
    if(diff.dot(heading) < 0) return false;
    return true;
  }
  
  boolean isTooClose(Paperplane plane) {
    return pos.distanceTo(plane.pos) < tooCloseDist;
  }
  
  void flock(ArrayList<SteeredPaperplane> planes) {
    Vec3D averageVelocity = vel.copy();
    Vec3D averagePosition = new Vec3D();
    int inSightCount = 0;
    int numPlanes = planes.size();
    for(int i = 0; i < numPlanes; i++) {
      Paperplane plane = planes.get(i);
      if(plane != this && isInSight(plane)) {
        averageVelocity = averageVelocity.add(plane.vel);
        averagePosition = averagePosition.add(plane.pos);
        if(isTooClose(plane)) flee(plane.pos);
        inSightCount++;
      }
    }
    if(inSightCount > 0) {
      averageVelocity = averageVelocity.normalizeTo(averageVelocity.magnitude() / inSightCount);
      averagePosition = averagePosition.normalizeTo(averagePosition.magnitude() / inSightCount);
      seek(averagePosition);
      steeringForce.add(averageVelocity.sub(vel));
    }
  }
}

void setup() {
  frameRate(30);
  size(600, 600, P3D);
  pixelDensity(displayDensity());
  colorMode(RGB);
  background(color(0, 135, 255));
  magenta = color(200, 35, 115);
  white = color(220, 220, 220);  // slightly grey. too white looks unrealistic!
  smooth();
  gfx = new ToxiclibsSupport(this);
  paperplaneMesh = createPaperplaneMesh();
  center = new Vec3D(width / 2, height / 2, 0);
  cam = new Vec3D(width / 2, height / 2, 400);
  targetBehindCam = new Vec3D(width / 2, height / 2, 500);
  magentaPlanes = new ArrayList<SteeredPaperplane>();
  for(int i = 0; i < numMagentaPlanes; ++i) {
    Vec3D vel = new Vec3D(random(-2, 2), random(-2, 2), random(-2, 2));
    magentaPlanes.add(
      new SteeredPaperplane(
        new Vec3D(random(0, width), random(0, height), random(-500, 500)),
        vel,
        random(15, 30),
        magenta
      )
    );
  }
  whitePlanes = new ArrayList<SteeredPaperplane>();
  for(int i = 0; i < numWhitePlanes; ++i) {
    Vec3D vel = new Vec3D(random(-2, 2), random(-2, 2), random(-2, 2));
    whitePlanes.add(
      new SteeredPaperplane(
        new Vec3D(random(0, width), random(0, height), random(-500, cam.z - 50)),
        vel,
        random(15, 30),
        white
      )
    );
  }
}

void draw() {
  colorMode(RGB);
  background(color(0, 135, 255));
  setupLights();
  setupCamera();
  if(frameCount > 42 * 30 && frameCount < 50 * 30) {
    // everybody rush to the center!
    for(SteeredPaperplane plane : magentaPlanes) {
      plane.seek(center);
    }
    for(SteeredPaperplane plane : whitePlanes) {
      plane.seek(center);
    }
  }
  if(keyPressed) {
    if(key == 'c') {
      // everybody rush to the center!
      for(SteeredPaperplane plane : magentaPlanes) {
        plane.seek(center);
      }
      for(SteeredPaperplane plane : whitePlanes) {
        plane.seek(center);
      }
    }
    if(key == 'm') {
      // fly towards the camera!
      for(SteeredPaperplane plane : magentaPlanes) {
        plane.seek(targetBehindCam);
      }
      for(SteeredPaperplane plane : whitePlanes) {
        plane.seek(targetBehindCam);
      }
    }
  }
  for(SteeredPaperplane plane : magentaPlanes) {
    plane.flock(magentaPlanes);
    plane.update();
    plane.display();
  }
  for(SteeredPaperplane plane : whitePlanes) {
    plane.flock(whitePlanes);
    plane.update();
    plane.display();
  }
  saveFrame("frames/f#####.png");
}

void setupCamera() {
  camera(cam.x, cam.y, cam.z, center.x, center.y, center.z, 0, 1, 0);
}

void setupLights() {
  shininess(0.7);
  ambientLight(255, 255, 255);
  directionalLight(255, 255, 255, -1, 1, -1);
}

TriangleMesh createPaperplaneMesh() {
  // draw a simple paper plane shape in 3D
  float alpha = radians(2);
  TriangleMesh paperplaneMesh = new TriangleMesh();
  paperplaneMesh.addFace(
    new Vec3D(0, 0, 0),
    new Vec3D(-sin(PI / 8 + alpha) / cos(PI / 4), cos(PI / 8 + alpha) / cos(PI / 4), 0),
    new Vec3D(-sin(alpha) / cos(PI / 8), cos(alpha) / cos(PI / 8), 0)
  );
  paperplaneMesh.addFace(
    new Vec3D(0, 0, 0),
    new Vec3D(-sin(alpha) / cos(PI / 8), cos(alpha) / cos(PI / 8), 0),
    new Vec3D(0, cos(PI / 8), -sin(PI / 8))
  );
  paperplaneMesh.addFace(
    new Vec3D(0, 0, 0),
    new Vec3D(sin(alpha) / cos(PI / 8), cos(alpha) / cos(PI / 8), 0),
    new Vec3D(0, cos(PI / 8), -sin(PI / 8))
  );
  paperplaneMesh.addFace(
    new Vec3D(0, 0, 0),
    new Vec3D(sin(PI / 8 + alpha) / cos(PI / 4), cos(PI / 8 + alpha) / cos(PI / 4), 0),
    new Vec3D(sin(alpha) / cos(PI / 8), cos(alpha) / cos(PI / 8), 0)
  );
  return paperplaneMesh;
}