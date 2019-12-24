# Import dependencies
from flask import Flask, render_template, request, flash, redirect, url_for, jsonify, send_from_directory, json
import config

# Initialise app
app = Flask(__name__, static_url_path='/static')
# Get configuration
app.config.from_object('config.ProductionConfig')


@app.route('/', methods=['GET'])
def index():
    # error handling
    try:
        return render_template('home.html')
    except:
        return render_template('500.html'), 500


# Routes for google analytics
@app.route('/google51951de21c061dc9.html', methods=['GET'])
def google_gsuite_verification():
    return render_template('google51951de21c061dc9.html')

@app.route('/google087c96628ea965db.html', methods=['GET'])
def google_webmaster_tools_verification():
    return render_template('google087c96628ea965db.html')

# Generic error handling routes
@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_server_error(e):
    return render_template('500.html'), 500

if __name__ == '__main__':
       app.run()
