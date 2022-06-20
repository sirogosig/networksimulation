import garciadelcastillo.dashedlines.*;
DashedLines dash;

ArrayList<Tree> trees;
ArrayList<Tag> tags;


float globalScale = 1.;
float eraseRadius = 30;
String tool = "start";

int tag_diameter;
int tree_diameter;
int commRadius;
int inspected_tag_index=-1; // Used to draw the currently inspected tag's suggest new cam location

//Toggles :
//boolean option_friend = true;

// Messages parameters
int messageTimer = 0;
String messageText = "";
String inspectionText = "";


void setup () {
  size(1300, 731); //Ratio of 1.777..7..7
  textSize(16);
  recalculateConstants();
  tags = new ArrayList<Tag>();
  trees = new ArrayList<Tree>();
  placeTreesnTags();
  dash = new DashedLines(this);
  dash.pattern(2, 3);
}

void recalculateConstants () {
  tag_diameter=(int) (8.*globalScale);
  tree_diameter=(int) (12.*globalScale);

  commRadius = (int) (220.*globalScale);
}


void placeTreesnTags() {
  for (int x = 100; x < width - 50; x+= 80) {
    for (int y = 100; y < height - 100; y+= 80) {
      boolean tagged=false;
      int randint=(int)random(5);
      if (randint==1) {
        tagged=true;
      }
      trees.add(new Tree(x + random(-30, 30), y + random(-30, 30), tagged));
      if (tagged) tags.add(trees.get(trees.size()-1).tag);
    }
  }
}

void draw () {
  // Black background:
  noStroke();
  colorMode(HSB);
  fill(0, 100);
  rect(0, 0, width, height);
  
  if (tool == "erase") {
    noFill();
    stroke(0, 100, 260);
    rect(mouseX - eraseRadius, mouseY - eraseRadius, eraseRadius * 2, eraseRadius *2);
    if (mousePressed) {
      erase();
    }
  } else if (tool=="tag_eraser") {
    noFill();
    stroke(0, 100, 260);
    rect(mouseX - eraseRadius, mouseY - eraseRadius, eraseRadius * 2, eraseRadius *2);
    if (mousePressed) {
      eraseTag();
    }
  } else if (tool == "trees") {
    noStroke();
    fill(20, 255, 90);
    ellipse(mouseX, mouseY, tree_diameter, tree_diameter);
  } else if (tool == "tags") {
    noStroke();
    fill(100);
    ellipse(mouseX, mouseY, tag_diameter, tag_diameter);
  }

  for (int i = 0; i <tags.size(); i++) {
    Tag current = tags.get(i);
    current.go();
    current.draw();
    if (i==inspected_tag_index){
      noFill();
      stroke(0, 255, 200); // Color = 0 (red)
      dash.ellipse(current.suggested_new_cam.x, current.suggested_new_cam.y, tag_diameter, tag_diameter);
    }
  }

  for (int i = 0; i <trees.size(); i++) {
    Tree current = trees.get(i);
    current.draw();
  }
  
  if (messageTimer > 0) {
    messageTimer--;
  }
  drawGUI();
}

void keyPressed () {
  if (key == 'c') {
    tool = "tags";
    message("Add tags");
  } else if (key == 'i') {
    tool = "inspect";
    message("Inspect tag");
  } else if (key == 't') {
    tool = "trees";
    message("Place trees");
  } else if (key == 'e') {
    tool = "erase";
    message("Eraser");
  } else if (key == 'z') {
    tool = "tag_eraser";
    message("Tag eraser");
  } else if (key == '-') {
    message("Decreased scale");
    globalScale *= 0.8;
  } else if (key == '=') {
    message("Increased Scale");
    globalScale /= 0.8;
  }
  //else if (key == '1') {
  //  option_friend = option_friend ? false : true;
  //  message("Turned friend allignment " + on(option_friend));
  else if (key == 'r') { // Reset
    n_tags=0;
    tags = new ArrayList<Tag>();
    trees = new ArrayList<Tree>();
    placeTreesnTags();
  }
  recalculateConstants();
}

void drawGUI() {
  textSize(16);
  if (messageTimer > 0) {
    fill((min(30, messageTimer) / 30.0) * 255.0);

    text(messageText, 10, height - 25);
  }
  fill(255.0); // Text color
  text(inspectionText, 150, height - 45);
  if (inspectionText!="") {
    noFill();
    stroke(255.0);
    rect(140, height - 65, 300, 60);
  }
  fill(255.0); // Text color
  text("Total trees: " + trees.size(), 950, height - 25);
  text("Total tags: " + tags.size(), 730, height - 25);
}

String s(int count) {
  return (count != 1) ? "s" : "";
}

//String on(boolean in) {
//  return in ? "on" : "off";
//}

void mousePressed () {
  switch (tool) {
  case "tags":
    int index = getAimedTreeIndex(); // Returns the index of the tree in trees aimed by the mouse
    trees.get(index).tag(); // Create Tag object associated with aimed_tree
    tags.add(trees.get(index).tag); // Add this new object to the list of tags
    break;

  case "trees":
    trees.add(new Tree(mouseX, mouseY, false));
    break;

  case "inspect":
    //Tree aimed_tree_ = getAimedTree(mouseX,mouseY);
    inspection();
    break;
  }
}

void erase () {
  for (int i = tags.size()-1; i > -1; i--) {
    Tag t = tags.get(i);
    if (abs(t.tree.pos.x - mouseX) < eraseRadius && abs(t.tree.pos.y - mouseY) < eraseRadius) {
      tags.remove(i);
    }
  }

  for (int i = trees.size()-1; i > -1; i--) {
    Tree t = trees.get(i);
    if (abs(t.pos.x - mouseX) < eraseRadius && abs(t.pos.y - mouseY) < eraseRadius) {
      trees.remove(i);
    }
  }
}

void eraseTag () {
  for (int i = trees.size()-1; i > -1; i--) {
    Tree t = trees.get(i);
    if (abs(t.pos.x - mouseX) < eraseRadius && abs(t.pos.y - mouseY) < eraseRadius) {
      trees.get(i).tagged=false;
    }
  }

  for (int i = tags.size()-1; i > -1; i--) {
    Tag t = tags.get(i);
    if (abs(t.tree.pos.x - mouseX) < eraseRadius && abs(t.tree.pos.y - mouseY) < eraseRadius) {
      tags.remove(i);
    }
  }
}

void message (String in) {
  messageText = in;
  messageTimer = (int) frameRate * 3;
}

void inspection () {
  inspected_tag_index = getAimedTagIndex(); // Returns the index of the tag in tags aimed by the mouse
  Tag aimed_tag=tags.get(inspected_tag_index);
  String tag_id="Tag ID: "+aimed_tag.id;
  String vp = "Vuln prob: "+aimed_tag.vuln_prob;
  String hops="Onehops: "+aimed_tag.onehops.size() + "  Twohops: "+aimed_tag.twohops.size();
  inspectionText=tag_id + "    " +vp + '\n'+ hops;
}

int getAimedTreeIndex() {
  float shortest_distance=height*width;
  PVector aimed_pos= new PVector(mouseX, mouseY);
  int aimed_tree_index=0;

  for (int i = 0; i<trees.size(); i++) {
    float distance = PVector.dist(trees.get(i).pos, aimed_pos);
    if (distance<shortest_distance) {
      shortest_distance=distance;
      aimed_tree_index=i;
    }
  }
  return aimed_tree_index;
}

int getAimedTagIndex() {
  float shortest_distance=height*width;
  PVector aimed_pos= new PVector(mouseX, mouseY);
  int aimed_tag_index=0;

  for (int i = 0; i<tags.size(); i++) {
    float distance = PVector.dist(tags.get(i).tree.pos, aimed_pos);
    if (distance<shortest_distance) {
      shortest_distance=distance;
      aimed_tag_index=i;
    }
  }
  return aimed_tag_index;
}
